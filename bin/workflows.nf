nextflow.enable.dsl=2

script_folder = "$baseDir/bin"

include {collect_data} from "$script_folder/processes.nf"
include {fill_image_gaps} from "$script_folder/processes.nf"
include {cellpose_segment} from "$script_folder/processes.nf"
include {extract_sc_data} from "$script_folder/processes.nf"

workflow data_collection{
	take:
		input_path
    main:
        collect_data(input_path)
	emit:
		data_csv = collect_data.out.metadata_csv 		
}

workflow segmentation{
    take:
		sample_name
		model_name
		probability
		diameter
		do_zip
		dapi_path
    main:
        cellpose_segment(sample_name, model_name, probability,
			diameter, do_zip, dapi_path)
    emit:
        mask_images = cellpose_segment.out.mask_image
		roi_zips = cellpose_segment.out.roi_zip
}

workflow gap_filling{
    take:
		sample_name
		dapi_path
    main:
        fill_image_gaps(sample_name, dapi_path)
    emit:
        gap_filled_image = fill_image_gaps.out.filled_image
}

workflow sc_data_extraction{
    take:
       sample_name
	   mask_image
	   counts

    main:
        extract_sc_data(sample_name, mask_image, counts)
    emit:
         sc_data = extract_sc_data.out.sc_data
}

