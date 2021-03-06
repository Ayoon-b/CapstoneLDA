
rm(list=ls())
library(plyr)
library(stringr)
library(KoNLP)
library(LDAvis)
library(showtext)
library(lda)
library(topicmodels)
library(servr)
library(RColorBrewer)
library(treemap)
library(extrafont)
library(shiny)
library(shinydashboard)
require(showtext) #R샤이니에서 한글 안깨지게 하는 코드
library(tm)
font_add_google(name='Nanum Gothic', regular.wt=400,bold.wt=700)
showtext_auto()
showtext_opts(dpi=112)

bookName <- "아몬드"
setwd(dirname(rstudioapi::getSourceEditorContext()$path)) #불러들일경로 (negative,positive.txt여기에있어야함)
path <- file.path(dirname(rstudioapi::getSourceEditorContext()$path))



kor <- list.files(file.path(path, bookName))  
kor.files <- file.path(path, bookName, kor)   
txt <- lapply(kor.files, readLines)
content<- readLines(file.path(path,bookName,"content.txt"))  
textCnt<-length(txt)-1        # 리뷰 수

topic <- setNames(txt, kor.files)  
topic <- sapply(topic, function(x) paste(x, collapse = " "))  

positive <- readLines("positive.txt")
positive=positive[-1] 
negative <- readLines("negative.txt")
negative=negative[-1]

if(file.exists(file.path(path,bookName,"bookData.RData"))==TRUE){
  print("존재")
  load(file.path(path,bookName,"bookData.RData"))
} else{
  print("존재하지않음 ")
  source('func_2.R',encoding="utf-8")
}

#----------------------json 생성-----------------------------------------------------------------------------------

# 
if(file.exists(file.path(path,bookName,"bookData.RData"))==FALSE){
  print("RData 파일 없음 - Json생성")
  json<-options(encoding='utf-8')                                           # 1
  
  json <- createJSON(phi = result$phi,                                      # 2
                     theta = result$theta,
                     doc.length = result$doc.length,
                     vocab = result$vocab,
                     term.frequency = result$term.frequency,encoding='UTF-8')
  serVis(json, out.dir = 'vis', open.browser = FALSE) # 경로에 vis 폴더 생성   3
}


#--------------------------------------------------------------------------------------------------------------------------------------
rjson<-readLines(file.path(path,"vis","lda.json"),encoding='utf-8') # vis 폴더에 있는 json 파일 불러오기  4
wordCnt<-length(result$vocab) # 토픽 단어 수
if(file.exists(file.path(path,bookName,"bookData.RData"))==TRUE){
  print("RData 있음")
  
} else{
  print("RData 존재하지않음- RData 생성 후 재시작")
  save.image(file = file.path(path,bookName,"bookData.RData"))
  quit(save = "no")
}

ui <- dashboardPage(skin="blue",
                    title= "리뷰 분석 시스템",
                    dashboardHeader(
                      title = "리뷰 분석 시스템",
                      titleWidth = 350
                    ),
                    dashboardSidebar(
                      width = 350,
                      h3(textOutput("bookName"),align="center"),
                      sidebarMenu(
                        menuItem("줄거리",tabName="bookContent",icon=icon("book")),
                        menuItem("토픽분석",tabName ="topic",icon=icon("dashboard")),
                        menuItem("감정분석",tabName ="sentiment",icon = icon("chart-pie"))
                        
                      )
                      
                      # textInput("bookName",label = "??? ??????",placeholder="??? ????????? ???????????????",width="90%"),
                      # actionButton("button",label = "??????",icon("paper-plane"))
                    ),
                    dashboardBody(
                      tags$head(tags$style(HTML('
                                                .main-header .logo {
                                                font-weight: bold;
                                                font-size: 24px;
                                                }
                                                
                                                #image{
                                                text-align: center;
                                                }
                                                #image img{
                                                width : 20em;
                                                }
                                                .box{
                                                margin-left: auto;
                                                margin-right: auto
                                                }
                                                #myChart{
                                                margin-left: 3em;
                                                }
                                                .box-header{
                                                text-align : center;
                                                }
                                                .box-header .box-title{
                                                font-size : 3em;
                                                }
                                                h1{
                                                padding-left: 1em;
                                                }
                                                h3{
                                                text-align : center;
                                                }
                                                
                                                .col-sm-6 .box{
                                                width:800px;;
                                                height:400px;
                                                }
                                                '))),
                      tabItems(
                        tabItem(tabName="bookContent",
                                h1("줄거리"),
                                hr(),
                                fluidRow(
                                  column(4,
                                         imageOutput("image")
                                  ),
                                  box(width = 6,
                                      textOutput("content")
                                  )     
                                ),
                                h1("데이터 정보"),
                                fluidRow(
                                  box(width=4,
                                      title = "사용된 리뷰 개수",
                                      background ="green",
                                      h3(textCnt,"개")
                                  ),
                                  box(width=4,
                                      title = "감정분석 단어 수",
                                      background ="blue",
                                      h3(1022,"개")
                                  ),
                                  box(width=4,
                                      title="추출 토픽 단어 개수",
                                      background="red",
                                      h3(wordCnt,"개")
                                  )
                                )
                        ),
                        tabItem(tabName = "topic",
                                h1("토픽 분석"),
                                hr(),
                                visOutput('myChart')
                        ),
                        
                        tabItem(tabName="sentiment",
                                h1("감정 분석"),
                                hr(),
                                splitLayout(
                                  style = "border: 1px solid silver;border-radius: 4px;",
                                  cellArgs = list(style = "padding: 4px"), 
                                  plotOutput(outputId = "sentiment_result"),plotOutput(outputId = "treemap"))
                        )
                      )
                      )
                      )

server <- function(input, output,session) {
  
  # observeEvent(input$button,{
  #   bookN <- input$bookName
  #   output$value <- renderText(bookN)
  #   output$text1 <- renderText({paste("??? ?????? ????????? ?????????????????????.")})
  #   output$text <- renderText({paste(bookN,"??? ?????? ????????? ?????? ???????????????")})
  # })
  output$bookName <- renderText(bookName)
  output$content <- renderText(content)
  output$textCnt <- renderText(textCnt)
  output$wordCnt <- renderText(wordCnt)
  output$image <- renderImage({
    list(
      src = file.path(path,bookName,"image.png"),
      contentType = "image/png",
      alt = "img"
    )
    
  },deleteFile = FALSE)
  
  output$myChart <- renderVis({
    with(result, rjson)
  })
  output$sentiment_result <- renderPlot({pie(sentiment_result, main="감정분석 결과",col=c("skyblue2","lightcoral","palegreen2"),
                                             label=paste(names(sentiment_percent),'', sentiment_percent,"%"),
                                             border = FALSE, radius=1)})
  
  output$treemap <- renderPlot({
    dset<-data.frame(keywords=names(sent.table), sentiment=sent.frequency)#괄호안에 데이터셋 넣으면됨()
    
    treemap(dset
            ,index=c("keywords")#괄호안에 "키워드" 로 바꾸면됨
            ,vSize=c("sentiment") # 타일의 크기 (언급횟수로 바꾸면 됨)
            ,vColor=c("sentiment") # 타일의 컬러
            ,type="value" # 타일 컬러링 방법
            ,title="감정"
            ,title.legend="빈도수"
            ,fontsize.title=15
            ,fontsize.legend=11
            ,fontsize.labels = 11
            ,fontface.labels = c("bold")
            ,fontfamily.labels = "NanumBarunGothic"  # 추가한 폰트 넣기
            ,fontfamily.title = "NanumBarunGothic"
            ,fontfamily.legend = "NanumBarunGothic"
            ,palette = "GnBu" #위에서 받은 팔레트 정보 입력
            ,border.col = "white") # 레이블의 배경색
  })
  # output$myChart <- renderVis(json)
  #output$value <- renderText({bookName})
  #output$value <- renderText({input$bookName})
  
}



shinyApp(ui, server)