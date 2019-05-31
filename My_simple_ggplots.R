# Data Import from file chosen by user

library(svDialogs)
# Get user input for file
testfile<-dlg_open()
# Convert to string value
testfile <- capture.output(testfile)[7]
if ((testfile)=="character(0)"){
  stop("File input cancelled")
}else{
#Remove invalid characters
testfile <- gsub("[\"]","",testfile)
testfile<-substring (testfile,5)

filename <- basename (testfile)
dir <- dirname (testfile)

# Set working directory accoding to file chosen
setwd(dir)

library(flowCore)

# this read.FCS() function imports the flow data:
raw_fcs<-read.FCS(filename, alter.names = TRUE)


# Preparation work for arcsinh transform
# Create list of parameters
columns<-colnames(raw_fcs)
# Remove "Time" column to avoid it being transformed
columns<-setdiff(columns,"Time")
# Remove "Cell_Length" column to avoid it being transformed
columns<-setdiff(columns,"Event_length")


# Read data into a data frame
FCSDATA <- as.data.frame(exprs(raw_fcs))

############ Optional Data Transform section

#Remove comments from code lines to transform using asinh
## Automatically estimate the logicle transformation based on the data
#lgcl <- estimateLogicle(raw_fcs, channels = c(columns))
## transform  parameters using the estimated logicle transformation
#raw_fcs_trans <- transform(raw_fcs, lgcl)
# Load into data frame
#FCSDATA <- as.data.frame(exprs(raw_fcs_trans))

########### End of optional Data Transform section



#Remove unnecessary parameter text - superseded by next function
#names(FCSDATA)[-1] <- sub("Di", "", names(FCSDATA)[-1])
# Create list of descriptions 
params<-parameters(raw_fcs)[["desc"]]
# Replace parameters with descriptions, keeping things like Time, Event Length unchanged
colnames(FCSDATA)[!is.na(params)] <- na.omit(params)

## Optionally remove Time, Event_Length & Gaussian Parameters
removecolumns <- c("Event_length", "Center", "Offset", "Width", "Residual")
FCSDATA <- FCSDATA[,!(names(FCSDATA) %in% removecolumns)]



# Get number of cell events (based on "193Ir)
cellevents<-as.data.frame(apply(FCSDATA, 2, function(c)sum(c!=0)))
colnames(cellevents) <-c("Events")
# Need to add one to the position because of the Time row
irpos<-grep("193Ir",na.omit(params))+1
cellevents<-cellevents$Events[irpos])
kcellevents <-round(cellevents/1000,0)



#Subsample using random 10% of original rows
#FCSDATA <- FCSDATA[sample(nrow(FCSDATA),nrow(FCSDATA)/10),]
#OR
#Subsample using a number of random rows, where the number is defined by numrows
numrows <- 1000
FCSDATA <- FCSDATA[sample(nrow(FCSDATA),numrows),]

# Melt the data into a continuous table, keeping Time for all values.
# This allows plotting all parameters using facet_wrap in the next section
library(reshape2)
fcsmelted <- melt(FCSDATA, id.var="Time", value.name = "intensity", variable.name="parameter")



#use ggplot2 to draw dot plot
library(ggplot2)


# Create colour scale for plot
# The extra "black" is needed to make the colour scale appear decent - otherwise it doesn't show
colfunc <- colorRampPalette(c("black", "black","black", "black", "black", "black", "black", "black",
                              "purple4", "purple4", 
                              "red", "yellow"))


#For converting time to mins on graph
div = (60*1000)

# For rounding time to a nice number on the x axis graphs
maxtime<-round(max(fcsmelted$Time)/div)

# Now that we have the total time, we can estimate the number of cell events/sec
eventspersec <- round(cellevents/maxtime/60,0)


## Plot x as Time and Y as intensity
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
  # Contour lines if desired
  # geom_density2d(colour="black", bins=3)  +  
  # Repeat for all parameters...
  facet_wrap("parameter") +
  # ...and allow each to be on their own Y axis scale
  # Note that free scales increases the processing time substantially
  #facet_wrap(scales="free")+
  # Force Y axis to start at zero
  ylim(0,NA) +
  # And scale y to log, displaying numbers rather than notation
  scale_y_log10(labels=scales::comma) + 
  # Zoom plot to only the values of interest
  coord_cartesian(ylim=c(1, max(fcsmelted$intensity)))+
  # Hide Y axis values if desired
  #theme(axis.text.y = element_blank(), axis.ticks = element_blank()) +
  # Hide legend
  theme(legend.position = "none") +
  # Hide Y axis label
  ylab(NULL) +
  # Change X axis label
  xlab("Time (min)")+
  ggtitle(filename)

}

if(length(cellevents)==0){
  stop("No cell events detected - file may not be CyTOF?")
}else{
message <- paste(kcellevents,"thousand cell events","and",eventspersec,"events/sec")
dlg_message(message)
}