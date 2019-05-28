
library(flowCore)

# import the data 
# this read.FCS() function imports the flow data
setwd("C:/Users/3054270/Documents/Machines/Helios/Cassie")
raw_fcs<-read.FCS("OP01_ILC01_190516_cat.fcs", alter.names = TRUE)

# Read in panel info from Excel file
#library(readxl)
#setwd("C:/Users/3054270/Documents/Tech Documents/Fluidigm Helios CyTOF/Sample Prep")
#markers <- read_excel("mouse_ab_cytof.xlsx")


# Create list of parameters
columns<-colnames(raw_fcs)
# Remove "Time" column to avoid it being transformed
columns<-setdiff(columns,"Time")
# Remove "Cell_Length" column to avoid it being transformed
columns<-setdiff(columns,"Event_length")



## Automatically estimate the logicle transformation based on the data
#lgcl <- estimateLogicle(raw_fcs, channels = c(columns))
## transform  parameters using the estimated logicle transformation
#raw_fcs_trans <- transform(raw_fcs, lgcl)
# Load into data frame
#FCSDATA <- as.data.frame(exprs(raw_fcs_trans))
# OR
# Don't transform - just load into data frame
FCSDATA <- as.data.frame(exprs(raw_fcs))

#Remove unnecessary parameter text
names(FCSDATA)[-1] <- sub("Di", "", names(FCSDATA)[-1])


#Subsample using random 10% of original rows
#FCSDATA <- FCSDATA[sample(nrow(FCSDATA),nrow(FCSDATA)/10),]
#OR
#Subsample using random x original rows
numrows <- 1000
FCSDATA <- FCSDATA[sample(nrow(FCSDATA),numrows),]

# Melt the data into a continuous table, keeping Time for all values.
# This allows plotting all parameters using facet_wrap in the next section
library(reshape2)
fcsmelted <- melt(FCSDATA, id.var="Time", value.name = "intensity", variable.name="parameter")

#use ggplot2 to draw dot plot
library(ggplot2)


# Create colour scale
# The extra "black" is needed to make the colour scale appear decent - otherwise it doesn't show
colfunc <- colorRampPalette(c("black", "black","black", "black", "black", "black", "black", "black",
                              "purple4", "purple4", 
                              "red", "yellow"))


#For converting time to mins on graph
div = (60*1000)

# For rounding time to a nice number on the x axis graphs
maxtime<-round(max(fcsmelted$Time)/div)



ggplot(fcsmelted, aes(x=Time/div, y=intensity)) +
  # Only label 0 and max on X Axis
  scale_x_continuous(breaks=seq(0,maxtime,maxtime)) +
  # Plot all points
  geom_point(shape=".")+
  # Fill with transparent colour fill using density stats 
  # ndensity scales each graph to its own min/max values
  stat_density2d(geom="raster", aes(fill=..ndensity.., alpha = ..ndensity..), contour = FALSE) +
  # Produces a colour scale based on the colours in the colfunc list
  scale_fill_gradientn(colours=colfunc(128)) + 
  # Contour lines
  # geom_density2d(colour="black", bins=3)  +  
  # Repeat for all parameters and allow each to be on their own Y axis scale
  # Note that free scales increases the processing time substantially
  facet_wrap("parameter", scales="free") +
  # Force Y axis to start at zero
  ylim(0,NA) +
  # And scale y to log, displaying numbers rather than notation
  scale_y_log10(labels=scales::comma) + 
  # Hide Y axis values
  #theme(axis.text.y = element_blank(), axis.ticks = element_blank()) +
  # Hide legend
  theme(legend.position = "none") +
  # Hide Y axis label
  ylab(NULL) +
  xlab("Time (min)")
