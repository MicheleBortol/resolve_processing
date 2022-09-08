nextflow.enable.dsl=2

script_folder = "$baseDir/bin"

include {data_collection} from "$script_folder/workflows.nf"
include {segmentation} from "$script_folder/workflows.nf"
include {sc_data_extraction} from "$script_folder/workflows.nf"

Closure compare_file_names = {a, b -> a.name <=> b.name}

workflow {
	data_collection(params.input_path)
    sample_metadata = data_collection.out.data_csv \
	    | splitCsv(header:true) \
		| multiMap { row-> 
			sample: row.sample
			dapi: row.dapi
			counts: row.counts}

	samples=sample_metadata.sample.toSortedList().flatten().view()
	dapi=sample_metadata.dapi.toSortedList().flatten().view()
	counts=sample_metadata.counts.toSortedList().flatten().view()

	segmentation(sample_metadata.sample, params.model_name, \
		params.probability_threshold, params.cell_diameter, \
		params.do_zip, sample_metadata.dapi)

	
	cell_masks = segmentation.out.mask_images
		.toSortedList(compare_file_names).flatten().view()
	roi_zips = segmentation.out.roi_zips
		.toSortedList(compare_file_names).flatten().view()

	sc_data_extraction(samples, cell_masks, counts)
}
