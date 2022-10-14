import argparse
import numpy as np
import cv2
import tensorflow as tf
from skimage import exposure, morphology, segmentation, io
from deepcell.applications import Mesmer

def claher(img):
	"""
	Runs Contrast Limited Adaptive Histogram Equalization (CLAHE)
	on the image and converts it to 8bit
	"""
	img = exposure.equalize_adapthist(img, kernel_size = 127, clip_limit = 0.01, nbins = 256)
	img = img / img.max() #normalizes img in range 0 - 255
	img = 255 * img
	img = img.astype(np.uint8)
	return img

def trim(image):
	"""
	Sets to 0 all pixels at the edges in place.
	"""
	image[0:, 0]                    = 0
	image[0:, image.shape[1] - 1]   = 0
	image[0, 0:]                    = 0
	image[image.shape[0] - 1, 0:]   = 0

def get_arguments():
	"""
	Parses and checks command line arguments, and provides an help text.
	Assumes 2 and returns 2 positional command line arguments:
	tiff_path = Path to the tiff file
	output_mask_file = Path to output the cell mask
	"""
	parser = argparse.ArgumentParser(description = "Performs 2D segmentation with MESMER.")
	parser.add_argument("tiff_path", help = "path to the image to segment")
	parser.add_argument("output_mask_file", help = "path to the cell mask output")
	args = parser.parse_args()
	return args.tiff_path, args.output_mask_file

if __name__ == "__main__":
	tiff_path, output_mask_file = get_arguments()

	# Load the input image
	print("Loading the image.")
	img = io.imread(tiff_path)

	# Perform Local Contrast Enhancment on the input image
	print("Running CLAHE the image.")
	img = claher(img)

	# Reshape the image to: 4D [batch, x, y, channel]
	# We use a 0 channel as membrane channel
	print("Reshape the image.")
	img = np.stack([img, np.zeros_like(img)], axis = -1)
	img = np.expand_dims(img, 0)

	# Define the model
	print("Initializing  the model.")
	model = tf.keras.models.load_model('/keras_models/MultiplexSegmentation')
	app = Mesmer(model)

	# Apply the model
	print("Segmenting cells.")
	mask = app.predict(img, image_mpp = 0.138) # 0.138 um per pixel for resolve
	mask = mask[0,:,:,0]

	# Remove isolated pixels and too small cells
	print("Cleaning the segmentation mask.")
	trim(mask)
	cell_number = np.amax(mask, axis = None) + 1
	canvas = np.zeros_like(mask)
	for cell_id in range(1, cell_number):
		canvas[np.where(morphology.remove_small_objects(mask == cell_id, 10) != 0)] = cell_id
	mask, _, _ = segmentation.relabel_sequential(canvas, offset = 1)

	# save mask
	print("Saving mask.")
	io.imsave(output_mask_file, mask)
