# KiCad-Stencils
A utility script to create the archive of Gerber files ready for uploading to OSH Stencils

As of KiCAD 5.0, the External Plugins menu is only available to the nightly builds and not the stable release. So this script can only be ran from the Tools->Scripting Console window and execute the following command. Note the exact path to the script file is required.

`>>> execfile('/path/to/script/file/oshstencil.py')`

For the nighly build, (Ubuntu), the oshstencil_plugin.py can be copied to the` ~/.kicad_plugins` directory. Either restart KiCAD or choose Tools->External Plugins...->Refresh Plugins and the options for "Generate the OSH Stencils Archive" should appear.
These notes my not reflect the current version of KiCAD for different platforms.

