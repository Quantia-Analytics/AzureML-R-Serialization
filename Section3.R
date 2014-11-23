# If running in ML Studio uncomment the first line with maml.mapInputPort().
cadairydata <- maml.mapInputPort(1)

## Create a new column as a POSIXct object
cadairydata$Time <- as.POSIXct(strptime(paste(as.character(cadairydata$Year), "-", as.character(cadairydata$Month.Number), "-01 00:00:00", sep = ""), "%Y-%m-%d %H:%M:%S"))

cadairytrain <- cadairydata[1:216, ]

str(cadairytrain)

Ylabs  <- list("Log CA Cotage Cheese Production, 1000s lb",
               "Log CA Ice Cream Production, 1000s lb",
               "Log CA Milk Production 1000s lb",
               "Log North CA Milk Milk Fat Price per 1000 lb")

Map(function(y, Ylabs){plot(cadairytrain$Time, y, xlab = "Time", ylab = Ylabs, type = "l")}, cadairytrain[, 4:7], Ylabs)

######################################
## This code is for model exploritory analysis and should
## not be included in the Azure Execute R Script module.

# milk.lm <- lm(Milk.Prod ~ Time + I(Month.Count^2) + I(Month.Count^3), data = cadairytrain)
# summary(milk.lm)

# milk.lm <- update(milk.lm, . ~ . - I(Month.Count^2))
# summary(milk.lm)

# milk.lm2 <- update(milk.lm, . ~ . + Month - 1)
# summary(milk.lm)

## End of exploritoray code. 
######################################

## Compute and plot the trend model. 
milk.lm <- lm(Milk.Prod ~ Time + I(Month.Count^3), data = cadairytrain)

## Compute and plot the seasonal model. 
milk.lm2 <- lm(Milk.Prod ~ Time + I(Month.Count^3) + Month - 1, data = cadairytrain)


serList <- function(serlist){
  ## Function to serialize list of R objects and returns a dataframe.
  ## The argument is a list of R objects. 
  ## The function returns a serialized list with two elements.
  ## The first element is count of the elements in the input list.
  ## The second element, called payload, containts the input list.
  ## If the serialization fails, the first element will have a value of 0,
  ## and the payload will be NA.
  
  ## Messages to use in case an error is encountered.
  messages  <- c("Input to function serList is not list of length greater than 0",
                 "Elements of the input list to function serList are NULL or of length less than 1",
                 "The serialization has failed in function serList")
  
  ## Check the input list for obvious problems
  if(!is.list(serlist) | is.null(serlist) | length(serlist) < 1) {
    warning(messages[1])
    return(data.frame(as.integer(serialize(list(numElements = 0, payload = NA), connection = NULL))))}
  
  ## Find the number of objects in the input list.
  nObj  <-  length(serlist)

  ## Serialize the output list and return a data frame.
  ## The serialization and assignment are wrapped in tryCatch
  ## in case anything goes wrong. 
  tryCatch(outframe <- data.frame(payload = as.integer(serialize(list(numElements = nObj, payload = serlist), connection=NULL))),
             error = function(e){warning(messages[3])
                                 outframe <- data.frame(payload = as.integer(serialize(list(numElements = 0, payload = NA), connection=NULL)))}
           )
  outframe
}

## serialize a list of the linear models into a data frame.
outFrame <- serList(list(milk.lm = milk.lm, milk.lm2 = milk.lm2))

## The following line should be executed only when running in
## Azure ML Studio. 
maml.mapOutputPort('outFrame') 
