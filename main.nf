nextflow.enable.dsl=2

script_folder = "$baseDir/bin"

include {data_collection} from "$script_folder/workflows.nf"
include {gap_filling} from "$script_folder/workflows.nf"
include {segmentation} from "$script_folder/workflows.nf"
include {roi_making} from "$script_folder/workflows.nf"
include {sc_data_extraction} from "$script_folder/workflows.nf"

Closure compare_file_names = {a, b -> a.name <=> b.name}

workflow {
	// Data Collection
	data_collection(params.input_path)
    sample_metadata = data_collection.out.data_csv
		.splitCsv(header : true)
		.multiMap { row -> 
			sample: row.sample
			dapi: row.dapi
			counts: row.counts}

	samples = sample_metadata.sample.toSortedList().flatten().view()
	dapi = sample_metadata.dapi.toSortedList().flatten().view()
	counts = sample_metadata.counts.toSortedList().flatten().view()

	// Gap Filling with MindaGap
	gap_filling(samples, dapi)

	filled_images = gap_filling.out.gap_filled_image
		.toSortedList(compare_file_names).flatten().view()

	// Cell Segmentation
	segmentation(sample_metadata.sample, params.model_name, \
		params.probability_threshold, params.cell_diameter, \
		filled_images)
	cell_masks = segmentation.out.mask_images
		.toSortedList(compare_file_names).flatten().view()

	if(params.do_zip){
		roi_making(samples, cell_masks)
		roi_zips = roi_making.out.zipped_rois
			.toSortedList(compare_file_names).flatten().view()
	}    

	sc_data_extraction(samples, cell_masks, counts)
    single_cell_data = sc_data_extraction.out.sc_data
                .toSortedList(compare_file_names).flatten().view()
}
