## If running in ML Studio uncomment the first line with maml.mapInputPort().
## Get the data frame with the 2 models from port 1 and the data set from port 2.
modelFrame  <- maml.mapInputPort(1)
cadairydata <- maml.mapInputPort(2)

## comment out the following line if running in Azure ML.
# modelFrame <- outFrame

unserList <- function(inlist){
  ## Function unserializes a list of R objects
  ## which are stored in a column of a dataframe.
  ## The unserialized R objects are returned in a list.
  ## If the unserialize fails for any reason a value of
  ## NA is returned.
  
  ## Some messages to use in case of error. 
  messages <- c("Unserialization has failed in function unserList",
                "Function unserList has encountered an empty list")
  
  ## Unserialized the list. The unserialize and assignment are
  ## wrapped in tryCatch in case something goes wrong. 
  tryCatch(outList <- unserialize(as.raw(inlist$payload)),
           error = function(e){warning(messages[1]); return(NA)})
  
  ## Check if the list is empty, which indicates something went 
  ## wrong with the serialization provess.
  if(outList$numElements < 1 ) {warning(meassages[2]); return(NA)}
  
  outList$payload
}

modelList <- unserList(modelFrame)
  
if(class(modelList$milk.lm) == "lm"){
  milk.lm <- modelList$milk.lm
}else{
  stop("lm model was not correctly unserialized")
}
  
  
if(class(modelList$milk.lm2) == "lm"){
  milk.lm2 <- modelList$milk.lm2
}else{
  stop("lm model was not correctly unserialized")
}

## Add the PoSIXct time series object to the data frame.
cadairydata$Time <- as.POSIXct(strptime(paste(as.character(cadairydata$Year), "-", as.character(cadairydata$Month.Number), "-01 00:00:00", sep = ""), "%Y-%m-%d %H:%M:%S"))

## Make sure we have the factor variable defined.
cadairydata$Month  <- as.factor(cadairydata$Month)

## Subset to get training data.
cadairytrain <- cadairydata[1:216, ]

## With the models unpacked, compute predictions for the training data.
predict1  <- predict(milk.lm, cadairytrain)
predict2  <- predict(milk.lm2, cadairytrain)

plot(cadairytrain$Time, cadairytrain$Milk.Prod, xlab = "Time", ylab = "Log CA Milk Production 1000s lb", type = "l")
lines(cadairytrain$Time, predict1, lty = 2, col = 2)

plot(cadairytrain$Time, cadairytrain$Milk.Prod, xlab = "Time", ylab = "Log CA Milk Production 1000s lb", type = "l")
lines(cadairytrain$Time, predict2, lty = 2, col = 2)

## Compute predictions for the entire time series.
predict1  <- predict(milk.lm, cadairydata)
predict2  <- predict(milk.lm2, cadairydata)

## Compute and plot the residuals
residuals <- cadairydata$Milk.Prod - predict2
plot(cadairytrain$Time, residuals[1:216], xlab = "Time", ylab ="Residuals of Seasonal Model")

## Show the diagnostic plots for the model
plot(milk.lm2, ask = FALSE)

RMS.error <- function(series1, series2, is.log = TRUE, min.length = 2){
  ## Function to compute the RMS error or difference between two
  ## series or vectors. 
  
  messages <- c("ERROR: Input arguments to function RMS.error of wrong type encountered",
                "ERROR: Input vector to function RMS.error is too short",
                "ERROR: Input vectors to function RMS.error must be of same length",
                "WARNING: Funtion rms.error has received invald input time series.")
  
  ## Check the arguments. 
  if(!is.numeric(series1) | !is.numeric(series2) | !is.logical(is.log) | !is.numeric(min.length)) {
    warning(messages[1])
    return(NA)}
  
  if(length(series1) < min.length) {
    warning(messages[2])
    return(NA)}
  
  if((length(series1) != length(series2))) {
    warning(messages[3])
    return(NA)}
  
  ## If is.log is TRUE exponentiate the values, else just copy.
  if(is.log) {
    tryCatch( { 
      temp1 <- exp(series1)
      temp2 <- exp(series2) },
      error = function(e){warning(messages[4]); NA}
    )
  } else {
    temp1 <- series1
    temp2 <- series2
  }
  
  ## Compute the RMS error value. 
  tryCatch( {
    sqrt(sum((temp1 - temp2)^2) / length(temp1))}, 
    error = function(e){warning(messages[4]); NA})
}

## Compute the RMS error in a dataframe. 
## Include the row names in the first column so they will
## appear in the output of the Execute R Script.  
RMS.df  <-  data.frame(
  rowNames = c("Trend Model", "Seasonal Model"),
  Traing = c(
    RMS.error(predict1[1:216], cadairydata$Milk.Prod[1:216]),
    RMS.error(predict2[1:216], cadairydata$Milk.Prod[1:216])),
  Forecast = c(
    RMS.error(predict1[217:228], cadairydata$Milk.Prod[217:228]),
    RMS.error(predict2[217:228], cadairydata$Milk.Prod[217:228]))
)

RMS.df

## The following line should be executed only when running in
## Azure ML Studio. 
maml.mapOutputPort('RMS.df') 