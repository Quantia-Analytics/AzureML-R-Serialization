# Introduction

Azure ML contains many powerful machine learning and data manipulation modules. Analytics and data manipulation in Azure ML can be extended using R.  This combination provides the scalability, ease of use, and ease of deployment of Azure ML with the flexibility and deep analytics of R.

This tutorial will show you how to serialize and unserilize lists of R objects. In Azure ML, you can output a data frame from an Execute R Script module, and read this data frame into another Execute R Script module.  By serializing a list of R objects and placing it in a data frame, most any R objects can be passed from one Execute R Script to another.

A companion video on serialization and unserialization of R objects in Azure ML can be found [here](https://www.youtube.com/watch?v=vk9Ic1F9YTk&feature=youtu.be).

## Background

The discussion in this article uses the models created in my Quick Start Guide to R in Azure ML. If you have not already read my [Quick Start Guide to R in Azure ML Studio](http://azure.microsoft.com/en-gb/documentation/articles/machine-learning-r-quickstart). The code is available in this [Git repo](https://github.com/Quantia-Analytics/AzureML-R-Quick-Start).

Companion videos are available:

* [Using R in Azure ML](https://www.youtube.com/watch?v=G0r6v2k49ys). 
* [Time series model with R in Azure ML](https://www.youtube.com/watch?v=q-PJ3p5C0kY).

## Passing R objects between execute R scripts

There are a number of situations in which you will need to pass non-data-frame R objects from one Execute R Script to another.

If you create a computationally intensive model you will want to compute predictions from new data without recomputing the model. If you are familiar with R, you know that applying predict method on a model object computes predictions using new data values. By this process, predictions are separated from model computations.

There are also cases where R data objects with differing dimensions must be passed from one execute R Script to another. R data frames cannot be ‘ragged’, so objects of differing dimensions cannot be placed in a data frame. However, nearly arbitrary R data objects can be placed in a list.  This list can then be serialized, placed in a column of a data frame, and passed to another Execute R Script.


## Overview

In this document I present an example of serializing and unserializing a pair of R linear models. In the remaining sections we will discuss the following topics:

* The experiment started in the Quick Start Guide is briefly reviewed.
* Computing the models, serializing a list of the models, and outputting the models in a data frame.
* Unserializing the list of models.
* , and using the models to make predictions and evaluate the performance of the models.


----------
### Note

The complete R code for the examples for Sections 2, 3 and 5 are in the files called Section2.R, Section3.R, and Section4.R. You can open these files directly in RStudio.

----------

# The Experiment

As a starting point we will use the first portion of the experiment I discuss in the Quick Start Guide. Specifically, we will use the same data set and the first Execute R Script as a starting point. At the start, my experiment looks like the following figure.

![](http://i.imgur.com/tVWsvj2.png)

**Figure 2.1. Starting point for experiment.**

The R code in the execute R script is identical to the code discussed in Section 4 of the Quick Start Guide. This code is available, along with the rest of the code used in this article [here](https://github.com/Quantia-Analytics/AzureML-R-Quick-Start).

# Outputting Serialized Models

In this section we discuss the serialization and output of a list of models. The approach taken here is quite general and can be applied to almost any list of R objects. 
You may notice that the model creation and evaluation code discussed in this article is identical to the code discussed in Section 6 of the Quick Start Guide. The point here is to show how to separate the model creation from the prediction and evaluation using the serialization process. To this end, the model creation and evaluation code will now be split between two Execute R Script modules.

## Updating the experiment

To proceed, I added another Execute R Script module to my experiment. I then cut and pasted the R code into this module. The figure below shows my experiment with the code pasted in:

![](http://i.imgur.com/2PuckMS.png)

**Figure 3.1. Experiment with new Execute R Script Module.**

## 3.2.	Review of the models

In Section 6 of the Quite Start Guide I discussed the creation of two linear models. One model has trend terms. The other model adds a seasonal term for each month of the year. In the interest of brevity, I will highlight a few lines of code used to create the models.

A training dataset is created from the first 216 rows of the data. This leaves the last 12 months of the data to be used to evaluate the models. The following line of code creates this training set:

    cadairytrain <- cadairydata[1:216, ]

The two models are created in the following lines of code:

    milk.lm <- lm(Milk.Prod ~ Time + I(Month.Count^3), data = cadairytrain)
    milk.lm2 <- lm(Milk.Prod ~ Time + I(Month.Count^3) + Month - 1, data = cadairytrain)

In the second model the Month term captures the seasonal effect. The ‘-1’ terms removes the intercept term to prevent the model from being over determined.

## Serializing the model list

To pass R objects from one Execute R Script to another they must be serialized. The serialized objects are then assigned to the column of a data frame which can be output with the `maml.mapOutputPort()` function.

Once the model objects are computed we will serialize them and output them to another Execute R Script module. Then we can make some predictions and compare model performance.

The function shown below serializes a list of R objects.  The only argument is a list which can contain most any type of R object. The function returns a serialized list in a column of a data frame. The first element of the list, named “numElements”, is the count of the number of objects.  The second element, named “payload”, contains the serialized list of objects. If the serialization fails for any reason, the count will be 0 and the payload will contain an NA value.

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
        return(data.frame(as.integer(serialize(list(numElements     = 0, payload = NA), connection = NULL))))}
  
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

There are a few points I should make about this code:

* A list is constructed with two elements. The first element contains the number of elements in the input list. The second element, called “payload”, contains the input list.
* This list is serialized. The result of the serialization is a vector of raw values. This vector must be coerced to a type which Azure ML recognizes, in this case integer.
* The resulting integer vector is assigned to the column of a data frame named “payload”.  This data frame can then be output to from the Execute R Script.
* A fair amount of this code is defensive. If there is an obvious problem with the input list or the serialization fails for any reason, the function returns a serialized list with 0 as the first element and NA as the payload element. The 0 value signals to the unserialize function that there is a problem.


----------
###Warning!

Notice that I am being careful to state that ‘most any’ R object can be placed in a list and serialized. A primary exception is object size. If the serialized list exceeds the maximum size of a vector on your system, the serialization will fail.  In this case you might be able to divide the R objects into smaller lists, and create a data frame with several columns of serialized data.

----------

The code shown below outputs the serialized list of model objects. Using the serList() function a list containing the two linear models is serialized and assigned to a data frame. The data frame is then output:

    ## serialize a list of the linear models into a data frame.
    outFrame <- serList(list(milk.lm = milk.lm, milk.lm2 = milk.lm2))

    ## The following line should be executed only when running in
    ## Azure ML Studio. 
    maml.mapOutputPort('outFrame')

Let’s execute the code in this Execute R Script module and have a look at the result. Clicking on the Visualize item on the Results Dataset port menu of the Execute R Script module I see the following:

![](http://i.imgur.com/EbSitQp.png)

**Figure 3.2. Output of the model serialization process.**

The table being output is what we expect. There is a single column called “payload”. You can see some of the values. As these data are part of a serialized R list, this output is not human readable.

# Forecasting  and Model Evaluation

Now that we have serialized our models, let’s discuss how we unserialize the models and evaluate them. The evaluation of the models is explained further in Section 6 of the Quick Start Guide.

## Updating the experiment

I am adding another Execute R Script module to my experiment. I then cut and paste the code into the new module. The figure below shows my experiment with the code pasted in:

![](http://i.imgur.com/tlM3zdh.png)

**Figure 4.1.  Experiment with additional Execute R Script.**

Note that I made two connections to the new Execute R Script module. The output of the previous Execute R Script module is connected to the Dataset1 port. The output of the first Execute R Script, which performs the data preparation, is connected to the Dataset2 port.

## Reading data and unserializing the models

Let’s have a look at some of the code in this Execute R Script module. The first few lines of code read the input data frames:

    ## Get the data frame with the 2 models from port 1 and the data set from port 2.
    modelFrame  <- maml.mapInputPort(1)
    cadairydata <- maml.mapInputPort(2)

The input on port 1 is assigned to a data frame containing the serialized R objects. The input on port 2 is assigned to a data frame containing prepared data from the first Execute R Script module. 

Our next step is clearly to unserialize the models. To do this I created the following R function:

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

There are some points I would like to make about this function:

* Recall that we coerced the data type in the table output from the proceeding Execute R Script to integer. We must now coerce this data back to the raw type, before the unserialize() function is called. 
* The unserialization process is wrapped in tryCatch. If there is a failure, the function will return NA. 
* We check if the number of elements in the payload list is greater than 0. If not, this indicates something went wrong with the original serialization process. In this case, we have no alternative but to return an NA. 

In the following code I use the `unserList()` function to extract the serialized list from the modelFrame data frame:

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

Once the list of R model objects has been unserialized the class of the objects is verified in the following two blocks of code. If the models are of class `lm` they are assigned to more convenient names. These are the same names used for model evaluation in the Quick Start Guide. 

## Model evaluation

The rest of the code in this Execute R Script performs model evaluation. A number of charts are produced at the R Device port and RMS errors are output at the Results Dataset port. If you are interested, I discuss this code and the results in detail in Section 6 of the Quick Start Guide. 

We should run this experiment and make sure the results produced are the same as we produced with the experiment in the Quick Start Guide. Doing so produces the following output at the Results Dataset port:

![](http://i.imgur.com/UldNcoO.png)

**Figure 4.2. Results Dataset showing the RMS error.**

As we expected, the results are identical to those seen without the serialization and unserialization of the models.


