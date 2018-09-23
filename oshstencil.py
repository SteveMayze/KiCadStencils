
## execfile('D:\python\pcbnew\oshstencil.py')

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

board = pcbnew.GetBoard()
plot = board.GetPlotOptions()
filename = board.GetFileName()
path = os.path.dirname(filename)
os.chdir(path)

gerbersDir = plot.GetOutputDirectory()
print("Gerbers Dir = {}".format(gerbersDir))
gerbers = os.listdir( gerbersDir )

mask = ["F.Paste.gbr","B.Paste.gbr","Edge.Cuts.gbr",]

project_name = getProjectName(path)

archive_name =  "{}_stencil.zip".format(project_name)

print("Archive Name = {}".format(archive_name))

with zipfile.ZipFile(archive_name, 'w') as stencil_zip:
	for g in gerbers:
		gerber_type = g.rsplit('-', 1)[-1]
		if( gerber_type in mask ):
			print("adding {}".format(g))

			stencil_zip.write(os.path.join(gerbersDir, g))

zipfile.ZipFile.close(stencil_zip)
