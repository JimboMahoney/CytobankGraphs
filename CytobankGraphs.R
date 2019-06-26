#########################################################
### Installing and loading required packages
#########################################################

if (!require("svDialogs")) {
  install.packages("svDialogs", dependencies = TRUE)
  library(svDialogs)
}

if (!require("flowCore")) {
  if (!requireNamespace("BiocManager", quietly = TRUE))
    install.packages("BiocManager")
  
  BiocManager::install("flowCore")
}

if (!require("tidyverse")) {
  install.packages("tidyverse", dependencies = TRUE)
  library(tidyverse)
}

if (!require("reshape2")) {
  install.packages("reshape2", dependencies = TRUE)
  library(reshape2)
}

if (!require("ggplot2")) {
  install.packages("ggplot2", dependencies = TRUE)
  library(ggplot2)
}


# Data Import from file chosen by user

#library(svDialogs) # Moved to top 
# Get user input for file
testfile<-dlg_open()
# Convert to string value
testfile <- capture.output(testfile)[7]
{

if ((testfile)=="character(0)")
stop("File input cancelled")

#Remove invalid characters from file input location
testfile <- gsub("[\"]","",testfile)
testfile<-substring (testfile,5)

#Set file and directory
filename <- basename (testfile)
dir <- dirname (testfile)

# Set working directory accoding to file chosen
setwd(dir)

#library(flowCore) #Moved to top

# this read.FCS() function imports the flow data:
raw_fcs<-read.FCS(filename, alter.names = TRUE)


# Preparation work for arcsinh transform (columns is also used later for naming changes)
# Create list of parameters
columns<-colnames(raw_fcs)
# Remove "Time" column to avoid it being transformed
columns<-setdiff(columns,"Time")
# Remove "Cell_Length" and Gaussians column to avoid it being transformed
columns<-setdiff(columns,"Event_length")
columns<-setdiff(columns,"Cell_length")
columns<-setdiff(columns,"Center")
columns<-setdiff(columns,"Offset")
columns<-setdiff(columns,"Width")
columns<-setdiff(columns,"Residual")
## Remove FSC and SSC
removefscssc<-grep("FSC|SSC",columns,value=TRUE)
columns<-columns[! columns %in% removefscssc]



# Read data into a data frame
FCSDATA <- as.data.frame(exprs(raw_fcs))

############ Optional Data Transform section

#Remove comments from code lines to transform using logicle
## Automatically estimate the logicle transformation based on the data
#lgcl <- estimateLogicle(raw_fcs, channels = c(columns))
## transform  parameters using the estimated logicle transformation
#raw_fcs_trans <- transform(raw_fcs, lgcl)
# Load into data frame
#FCSDATA <- as.data.frame(exprs(raw_fcs_trans))

########### End of optional Data Transform section



#Remove unnecessary parameter text
names(FCSDATA)[-1] <- sub("Di", "", names(FCSDATA)[-1])
names(FCSDATA)[-1] <- sub("Dd", "", names(FCSDATA)[-1])
# Create list of channel / parameter descriptions 
params<-parameters(raw_fcs)[["desc"]]
# Replace parameters with descriptions, keeping things like Time, Event Length unchanged
colnames(FCSDATA)[!is.na(params)] <- na.omit(params)

# Determine whether data is CyTOF or Flow by presence of FSC
# isflow will be 0 for a CyTOF or greater than 1 if flow
isflow <-sum(grep("FSC",colnames(FCSDATA)))
# Determine whether data is pre CyTOF 3 (Helios) by presence of "Cell_length", rather than "Event_length"
isCyTOF2 <-sum(grep("Cell_length",colnames(FCSDATA)))

## Remove Time, Event_Length & Gaussian Parameters
removecolumns <- c("Event_length", "Center", "Offset", "Width", "Residual", "Cell_length")
FCSDATA <- FCSDATA[,!(names(FCSDATA) %in% removecolumns)]


## Remove FSC and SSC
# library(tidyverse) # Moved to top
FCSDATA <- FCSDATA %>% select(-contains("FSC"))
FCSDATA <- FCSDATA %>% select(-contains("SSC"))



# Get number of cell events (based on "193" - i.e. Iridium)
if(isflow==0){
  cellevents<-as.data.frame(apply(FCSDATA, 2, function(c)sum(c!=0)))
  colnames(cellevents) <-c("Events")
  # Note that this only works correctly because "Time" has been removed by a previous step - otherwise the position would be wrong.
  irpos<-grep("193",columns)
  cellevents<-cellevents$Events[irpos]
  kcellevents <-round(cellevents/1000,0)
}


#For converting FCS time to mins - flow uses 10ms units, CyTOF uses ms
if(isflow>0){
  div = (60*100)
}else{
  div = (60*1000)
}

# Find total acquisition time
maxtime<-round(max(FCSDATA$Time)/div,1)

# Now that we have the total time, we can calculate the number of cell events/sec
if(isflow==0){
  eventspersec <- round(cellevents/maxtime/60,0)
}


# Create number formatted list of intensity values and event counts
Medianintensitylist<-c(format(c(round(apply(FCSDATA,2,FUN=median)),1),big.mark=",",trim=TRUE))
Meanintensitylist <- c(format(c(round(colMeans(FCSDATA)),1),big.mark = ",",trim=TRUE))
EventSecList <- c(format(c(round((colSums(FCSDATA !=0)/(maxtime*60)),0),trim=TRUE)))
# Remove the last row that is added by format
Meanintensitylist<-Meanintensitylist[-length(Meanintensitylist)]
Medianintensitylist<-Medianintensitylist[-length(Medianintensitylist)]
EventSecList<-EventSecList[-length(EventSecList)]
# Create data frame for labels to print mean intensity on plots
datalabels <- data.frame(
  Meanintensity=c(Meanintensitylist),
  Medianintensity=c(Medianintensitylist),
  parameter = c(colnames(FCSDATA)),
  EventsPerSec = c(EventSecList)
)


#Calculate size of dataset
DataSizeM <- (ncol(FCSDATA)*nrow(FCSDATA))/1000000
#Subsample if dataset is large
if (DataSizeM>2.5){
  #using random 10% of original rows
  #FCSDATA <- FCSDATA[sample(nrow(FCSDATA),nrow(FCSDATA)/10),]
  #OR
  #Subsample using a number of random rows, where the number is defined by numrows
  numrows <- 5000
  FCSDATA <- FCSDATA[sample(nrow(FCSDATA),numrows),]
}



# Add a blank to the columns list to match its length to that of FCSDATA (i.e. the time row)
columns<-columns<-append(columns,"Time",after=0)
# Add back the original marker names
datalabels[,"OrigMarkers"]<-columns
# Remove Di / Dd
datalabels$OrigMarkers <- sub("Di", "", datalabels$OrigMarkers)
datalabels$OrigMarkers <- sub("Dd", "", datalabels$OrigMarkers)

# This is needed for pre-Helios data to ensure we don't mess with the parameter names
if (isCyTOF2>1){

  # Remove other symbols
  datalabels$OrigMarkers <- gsub("[[:punct:]]", "", datalabels$OrigMarkers)
  
  # Create a function to extract the last n characters from a string
  substrRight <- function(x, n){
    substr(x, nchar(x)-n+1, nchar(x))
  }
  # Extract only last 5 characters (i.e the element and mass) - this is clumsy and doesn't work well for flow data, which may have longer names for markers
  # But I can't figure out a way to remove duplicate text
  datalabels$OrigMarkers<-substrRight(datalabels$OrigMarkers,5)
  
  # Compare columns and keep only original markers if they are different
  datalabels$OrigMarkers<-ifelse(datalabels$parameter==datalabels$OrigMarkers,"",paste("/",datalabels$OrigMarkers))
  # Replace parameters column with orignal marker names / parameters
  datalabels[,"parameter"]<-paste(datalabels$parameter,datalabels$OrigMarkers)
} #End of flow data name comparison / CyTOF paramater rename loop

# Remove the OrigMarkers column as it's no longer needed
datalabels<-datalabels[,-5]


# Make sure the FCSDATA matches the datalabels
colnames(FCSDATA)<-datalabels$parameter

#Trim the trailing whitespace added by paste
colnames(FCSDATA)<-trimws(colnames(FCSDATA),"r")
datalabels$parameter<-trimws(datalabels$parameter,"r")


# Remove Time from labels
datalabels <- datalabels[!(rownames(datalabels) %in% "Time"),]
# Change rownames to numeric 
rownames(datalabels) <- 1:nrow(datalabels)
# Change parameters to factors to control facet order
datalabels$parameter<-as.factor(datalabels$parameter)



# Melt the data into a continuous table, keeping Time for all values.
# This allows plotting all parameters using facet_wrap in the next section
# library(reshape2) # Moved to op
fcsmelted <- melt(FCSDATA, id.var="Time", value.name = "intensity", variable.name="parameter")



#use ggplot2 to draw dot plot
# library(ggplot2) # Moved to top


# Create colour scale for plot
# The extra "black" is needed to make the colour scale appear decent - otherwise it doesn't show
colfunc <- colorRampPalette(c("black", "black","black", "black", "black", "black", "black", "black",
                              "purple4", "purple4", 
                              "red", "yellow"))


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
  ggtitle(filename) +
  # Add mean intensity values from previously calculated data table
  geom_label(data=datalabels,
            colour="black",
            fontface="bold",
            size=3,
            alpha=0.5,
            mapping=aes(maxtime/2,(max(fcsmelted$intensity))/1000,
                        label=paste("Mean =",Meanintensity,", Median =",Medianintensity,", Events/sec =",EventsPerSec)))
            


} # End of file cancel loop

# Create a pop-up with the cell (Ir) Events and rate.
if ((testfile)=="character(0)" || isflow>0 || length(cellevents)==0){
    stop("No cell events detected")
  }else{
  message <- paste(kcellevents,"thousand cell events","and",eventspersec,"events/sec")
  dlg_message(message)
  }


