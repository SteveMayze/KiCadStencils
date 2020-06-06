
## execfile('D:\python\pcbnew\oshpark.py')

import pcbnew
import os
import zipfile

def getProjectName(path):
	for root, dirs, files in os.walk(path):
		for filename in files:
			bname, extension = os.path.splitext(filename)
			if extension == '.pro':
				return os.path.join(root, bname)
	return None

class OSHParkPlugin(pcbnew.ActionPlugin):

	def defaults(self):
		self.name = 'Generate the OSH Park Archive'
		self.category = 'Packaging Utility'
		self.description = 'Will create an archive of the Gerber and the Edge Cut layer for sending to OSH Park or other Fab House'


	def Run(self):

		board = pcbnew.GetBoard()
		plot = board.GetPlotOptions()
		filename = board.GetFileName()
		path = os.path.dirname(filename)
		os.chdir(path)

		gerbersDir = plot.GetOutputDirectory()
		print("Gerbers Dir = {}".format(gerbersDir))
		gerbers = os.listdir( gerbersDir )

		mask = [
            ".drl",
            "B_Cu.gbr", 
            "B_Mask.gbr", 
            "F_Paste.gbr", 
            "B_SilkS.gbr", 
            "Edge_Cuts.gbr", 
            "F_Cu.gbr", 
            "F_Mask.gbr", 
            "B_Paste.gbr", 
            "F_SilkS.gbr", 
            "In1_Cu.gbr", 
            "In2_Cu.gbr",
        ]
		project_name = getProjectName(path)

		archive_name =  "{}_gerber.zip".format(project_name)

		print("Archive Name = {}".format(archive_name))

		with zipfile.ZipFile(archive_name, 'w') as stencil_zip:
			for g in gerbers:
				gerber_type = g.rsplit('-', 1)[-1]
				if( gerber_type in mask ):
					print("adding {}".format(g))

					stencil_zip.write(os.path.join(gerbersDir, g))

		zipfile.ZipFile.close(stencil_zip)

OSHParkPlugin().register()
