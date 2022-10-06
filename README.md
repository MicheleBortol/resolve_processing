# RESOLVE_tools

Tentative set of tools and scripts for analysing spatial transcriptomic data with the resolve platform
[Nextflow](https://www.nextflow.io/) pipeline which runs image segmentation with [cellpose](https://github.com/MouseLand/cellpose) and then counts the transcripts in each cell. The pipeline uses two Python3 scripts for:
+ Segmentation
+ Expression assignment = counting the transcripts in each cell

These scripts can be used independently or as part of the Nextflow pipeline provided.

*Dependencies*
+ [Nextflow](https://www.nextflow.io/)
+ [Singularity](https://docs.sylabs.io/guides/latest/user-guide/) 

The pipeline automatically fetches the following singularity container and uses it to run the scripts:

https://cloud.sylabs.io/library/michelebortol/resolve_tools/cellpose_skimage

The definition file is provided [here](https://github.com/MicheleBortol/RESOLVE_tools/blob/main/singularity/cellpose.def).


## Contents:
+ (1) [Nextflow pipeline](##Pipeline)
	+ (1.1) [Parameters](###Parameters)
	+ (1.2) [Input](###Input)
	+ (1.3) [Output](###Output)
	+ (1.4) [Example Run](###Example)
+ (2.2) [Scripts](##Scripts)
	+ (2.1) [Segmentation](###Segmentation)
	+ (2.2) [Expression assignment](###expression_assign)

## 1) Nextflow pipeline <a name="##Pipeline"></a>

### 1.1) Parameters <a name="##Parameters"></a>
For an example see the provided example config [file](https://github.com/MicheleBortol/RESOLVE_tools/blob/main/example.config)
    
*Input/output Parameters:*
+ `params.input_path` = Path to the resolve folder with the Panoramas to be processed
+ `params.output_path` = Path for output

*cellpose Segmentation Parameters:*
+ `params.model_name` = "cyto" (recommended) or any model that uses 1 DNA channel.
+ `params.probability_threshold` = floating point number between -6 and +6 see [cellpose threshold documentation](https://cellpose.readthedocs.io/en/latest/settings.html#mask-threshold).
+ `params.cell_diameter` = Cell diameter or `None` for automatic estimation, see [cellpose diameter documentation](https://cellpose.readthedocs.io/en/latest/settings.html#diameter).
+ `params.do_zip` =	`true` or `false`.  Set to false to skip making ImageJ ROIs (faster)
+ `params.output_path` = "output/nextflow_test"

### 1.2) Input <a name="##Input"></a>
Folder with the panoramas to be processed. All panoramas are expected to have:
+ DAPI image named: `Panorama_*_Channel3_R8_.tiff`
+ Transcripts coordinates named: `Panorama_*_results_withFP.txt`
    
### 1.3) Output <a name="##Output"></a>
In `params.output_path`: 
+ `sample_metadata.csv`: .csv file with one row per sample and 3 columns: sample (sample name), dapi (path to the dapi image), counts (path to the transcript coordinates)
+ For each sample a folder: `SAMPLE_NAME` with: 
	+ `SAMPLE_NAME-gridfilled.tiff` = Image with the registration grid lines smoothed out. 
	+ `SAMPLE_NAME-mask.tiff` = 16 bit segmentation mask (0 = background, N = pixels belonging to the Nth cell).
	+ `SAMPLE_NAME-roi.zip` (optional) = ImageJ ROI file with the ROIs numbered according to the segmentation mask.
	+ `SAMPLE_NAME-cell_data.csv` = Single cell data, numbered according to the semgentation mask.

### 1.4) Example <a name="##Example"></a>
`nextflow run main.nf -profile cluster -c test.config`
Breakdown:
+ `-profile cluster` = For running on a PBS based cluster like the CURRY cluster. Default is local execution.
+ `-c test.config` = Use the parameters specified in the `test.config` file. ALternatively, parameters can be passed from the command line.


## 2) Scripts <a name="#Scripts"></a>
Scripts used in the Nextflow pipeline, can also be run independently.

### 2.1) Segmentation <a name="##Segmentation"></a>
[Segmentation script](https://github.com/MicheleBortol/RESOLVE_tools/blob/main/bin/segmenter.py)
Just a wrapper around cellpose. It assumes the input is a single channel grayscale image with the nuclei. It requires the following positional arguments:
+ `tiff_path` = path to the image to segment
+ `model_name` = model to use for the segmentation			
+ `prob_thresh` = probability threshold
+ `cell_diameter` = cell diameter for cellpose and size filtering (None for automatic selection). Cells smaller than `cell_diameter / 2` are discarded
+ `output_mask_file` = path to the cell mask output
+ `output_roi_file` (optional) = path to the roi mask output or leave empty to skip (saves time).

The script:
1) Run CLAHE on the input image.
2) Segemnt with cellpose.
3) Remove cells smaller then `cell_diameter / 2`.
4) OPTIONAL: extract the ROIs and write them in ImageJ format as a zip file.


**Example**  
`python3.9 segmenter.py DAPI_IMAGE cyto 0 70 OUTPUT_SEGMENTATION_MASK_NAME OUTPUT_ROI_ZIP_NAME`

### 2.2) Expression assignment <a name="##expression_assign"></a>
[Expression assignment script](https://github.com/MicheleBortol/RESOLVE_tools/blob/main/bin/segmenter.py)
Counts the transcripts in each cell from the segmentation mask. Equivalent to the Polylux counts unless:
+ Overlapping ROIs
+ Transcripts outside the border of the image or lying exactly on the ROI border (resolution is 1 pixel)
It requires the following positional arguments:
+ mask_file = Path to the input mask file
+ transcript_file = Path to the input transcript file
+ output_file = Path to the output single cell data file
Notes:
+ Removes all transcripts whose coordinates fall outside the size of the mask.

**Example**  
` python3.9 extracter.py SEGMENTATION_MASK TRANSCRIPT_COORDINATE_FILE OUTPUT_FILE_PATH.csv`

To Do:
+ Add option to filter by Z coordinate?
+ Add option to filter by transcript quality?
+ Add option to count transcripts from ROIs? 


