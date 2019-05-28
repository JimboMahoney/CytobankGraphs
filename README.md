# CytobankGraphs
This is a beginner's (both to mass cytometry and R) attempt to recreate the plots like [Cytobank.](https://www.cytobank.org)

e.g.

<img src="https://raw.githubusercontent.com/JimboMahoney/CytobankGraphs/master/Plot.png"
  align="center" />

I wanted a simple way of getting an overview of every parameter. This could be from a CyTOF machine, like the Helios I'm using here, or a flow machine.

This script will:

1) Read in a specified FCS file
2) Optionally transform the data using a data-specific arcsinh
3) Subsample down to a user-specified number or proportion of events
4) Plot every parameter using a similar graphically representation and palette as cytobank

Since the parameters can be numerous (e.g. I'm using a dataset with 62 parameters), it's best to use the "Zoom" function to view the output in fullscreen.

Improvements / things to do:

The graphical representation isn't perfect. I need to figure out a way of making the plots more "dense" and / or having the density overlay better defined.



