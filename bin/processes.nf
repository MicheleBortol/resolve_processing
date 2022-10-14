script_folder = "$baseDir/bin"

process collect_data{

    memory { 1.GB }
    time '1h'
    
    publishDir "$params.output_path", mode:'copy', overwrite: true

    input:
		val(input_path)
	
    output:
        path("sample_metadata.csv", emit: metadata_csv)
    
    script:
    """
	echo "sample,dapi,counts" > sample_metadata.csv
	while IFS= read -d \$'\\0' -r DAPI
	do
		SAMPLE="\${DAPI##$input_path/Panorama_}"
		SAMPLE="\${SAMPLE%%_Channel3_R8_.tiff}"
		COUNTS="$input_path/Panorama_""\$SAMPLE""_results_withFP.txt"
		echo "\$SAMPLE,\$DAPI,\$COUNTS" >> sample_metadata.csv 
	done < <(find "$input_path/" -name "*_Channel3_R8_.tiff" -print0)
    """
}

process fill_image_gaps{

    memory { 8.GB * task.attempt }
    time '1h'

    errorStrategy { task.exitStatus in 137..143 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "$params.output_path/$sample_name", mode:'copy', overwrite: true
    container = "library://michelebortol/resolve_tools/cellpose_skimage:resolve_tools"

    input:
		val(sample_name)
		path(dapi_path)
	
    output:
        path("$sample_name-gridfilled.tiff", emit: filled_image)

    script:
    """
	python3.9 -u /MindaGap/mindagap.py $dapi_path 3 > gapfilling_log.txt
	mv *gridfilled.tif $sample_name-gridfilled.tiff

    """
}

process cellpose_segment{
    
    memory { 128.GB * task.attempt }
    time '72h'
    
    errorStrategy { task.exitStatus in 137..143 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "$params.output_path/$sample_name", mode:'copy', overwrite: true
    container = "library://michelebortol/resolve_tools/cellpose_skimage:resolve_tools"

    input:
		val(sample_name)
		val(model_name)
		val(probability)
		val(diameter)
		path(dapi_path)
	
    output:
        path("$sample_name-mask.tiff", emit: mask_image)

    script:
    """
	python3.9 -u $script_folder/segmenter.py $dapi_path $model_name $probability \
		$diameter $sample_name-mask.tiff > $sample_name-segmentation_log.txt
    """
}

process make_rois{
    
    memory { 128.GB * task.attempt }
    time '72h'
    
    errorStrategy { task.exitStatus in 137..143 ? 'retry' : 'terminate' }
    maxRetries 3

    publishDir "$params.output_path/$sample_name", mode:'copy', overwrite: true
    container = "library://michelebortol/resolve_tools/cellpose_skimage:resolve_tools"

    input:
		val(sample_name)
		path(mask_path)
	
    output:
        path("$sample_name-roi.zip", emit: roi_zip)
    
	script:
    
	"""
	python3.9 -u $script_folder/roi_maker.py $mask_path \
		$sample_name-roi.zip > $sample_name-roi-log.txt
    """
}

process extract_sc_data{

    memory { 16.GB * task.attempt }
    time '72h'

    publishDir "$params.output_path/$sample_name", mode:'copy', overwrite: true
    container = "library://michelebortol/resolve_tools/cellpose_skimage:resolve_tools"

    input:
        val(sample_name)
		path(mask_image_path)
		path(transcript_coord_path)

    output:
        path("$sample_name-cell_data.csv", emit: sc_data)

    script:

    """
	python3.9 $script_folder/extracter.py $mask_image_path $transcript_coord_path \
		${sample_name}-cell_data.csv > $sample_name-extraction_log.txt
    """
}

