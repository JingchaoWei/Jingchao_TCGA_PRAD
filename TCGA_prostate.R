# Mon Oct 29 17:17:30 2018 ------------------------------

rm(list=ls())
exp <- read.delim2("data_Xena/HiSeqV2.gz",row.names = 1, check.names = F,dec = '.',
                   colClasses = c('character',rep('numeric',550)))
phe <- read.delim2("data_Xena/PRAD_clinicalMatrix/PRAD_clinicalMatrix",check.names = F)
exp_t <- as.data.frame(t(exp))
exp_t$sampleID <- rownames(exp_t)
merge <- merge(phe,exp_t,by="sampleID",all=F)
save(exp,phe,merge,file = "PCa_TCGA.Rdata")
write.table(merge,file = "combined_TCGA_data.txt",quote = F,sep = "\t",row.names = F,col.names = T)


load("PCa_TCGA.Rdata")
up_gene <- read.delim('Query_Genes.txt',stringsAsFactors = F)
up_gene <- up_gene$Up.[1:9]

library(survival)
library(survminer)
library(ggplot2)
library(gplots)
library(gridExtra)

#用median分组
MySurvival <- function(gene){
  a <- isTRUE(gene %in% colnames(merge))
  merge$append=ifelse(merge[[gene]]>median(merge[[gene]]),'big','small')
  colnames(phe)
  sfit <- survfit(Surv(OS.time, OS)~append, data=merge)
  sfit
  summary(sfit)
  sfit_2 <- survfit(Surv(RFS.time, RFS)~append, data=merge)
  sfit_2
  summary(sfit_2)
  oa <- ggsurvplot(sfit, conf.int=F, pval=TRUE,data = merge,
             title=paste0("Overall Survival_",gene),combine = T)
  rf <- ggsurvplot(sfit_2, conf.int=F, pval=TRUE,data = merge,
           title=paste0("Recurrence/Disease Free Survival_",gene),combine = T)
  arrange_ggsurvplots(x = list(oa,rf),title = gene,nrow = 1,ncol = 2)
  print(paste0('Is ',gene,' in the dataset?  ',a))
  survival_data <- merge[,c('OS.time','OS','RFS.time','RFS',gene)]
  write.table(survival_data,file = paste0(gene,"_Survival_data.txt"),
              quote = F,sep = "\t",row.names = F)
}

pdf(file = "Survival_analysis_UpGenes.pdf",width = 14,onefile = T)
for (i in up_gene) {
  MySurvival(i)
}
dev.off()


# Thu Nov 01 14:27:40 2018 ------------------------------

#sample type t test : gene is character
get_data <- function(gene){
  whether_in <- isTRUE("sample_type" %in% colnames(phe))
  print(paste0("Is sample_type in phe? :",whether_in))
  data <- merge[,c('sample_type','sampleID',gene)]
  table(data$sample_type)
  data <- data[data$sample_type!='Metastatic',]
  data$sample_type <- factor(data$sample_type)
  write.table(data,file = paste0(gene,"_sample_type.txt"),quote = F,sep = "\t",row.names = F)
  return(data)
}


#t test
MyTtest <- function(gene){
  normal <- subset(data,subset = sample_type=="Solid Tissue Normal",select = gene)
  normal <- normal[,1]
  tumor <- subset(data,subset = sample_type=="Primary Tumor",select = gene)
  tumor <- tumor[,1]
  #var equal test
  var(tumor)
  var(normal)
  var.test(tumor,normal)#看方差是否相等，这里p<0.05, 表示方差不等，下面的var.equal要设为FALSE
  tmp <- ifelse(var.test(tumor,normal)$p.value>=0.05,"TRUE","FALSE")
  print(paste0('Is var of two groups equal? :',tmp))
  #t test
  t.test(tumor,normal,paired = F,var.equal = as.logical(tmp))
  pvalue_ttest <- t.test(tumor,normal,paired = F)$p.value
  pvalue_ttest <- format(pvalue_ttest, scientific = FALSE)#不采用科学计数法
  mean <- aggregate(data[[gene]],by=list(data$sample_type),FUN=mean)
  sd <- aggregate(data[[gene]],by=list(data$sample_type),FUN=sd)
  a <- ggplot(data=data,aes(x=sample_type,y=data[[gene]],fill=sample_type))+
    geom_boxplot()+
    ggtitle(gene)+
    theme(plot.title = element_text(hjust = 0.5))+
    annotate("text",x= 1.5, y= 0, label = paste0('pvalue=',pvalue_ttest))
  b <- ggplot(mean,aes(x=Group.1,y=x))+
    geom_bar(stat = "identity",width = 0.3,position = position_dodge(0.7))+
    geom_errorbar(aes(ymin=mean$x-sd$x,ymax=mean$x+sd$x),
                  width = 0.3,position = position_dodge(0.7))+
    ggtitle(gene)+
    theme(plot.title = element_text(hjust = 0.5))+
    annotate("text", x= 1.4, y= 0,label = paste0('pvalue=',pvalue_ttest))
  c <- ggplot(data=data,aes(x=sample_type,y=data[[gene]],fill=sample_type))+
    geom_dotplot(binaxis = "y",stackdir = "center",dotsize = 0.3)+
    ggtitle(gene)+
    theme(plot.title = element_text(hjust = 0.5))+
    annotate("text", x= 1.5, y= 0,label = paste0('pvalue=',pvalue_ttest))
  lay <- rbind(c(1,1,1,2,2),c(3,3,3,NA,NA))
  grid.arrange(a,b,c,nrow = 2,ncol=2,name=gene,layout_matrix = lay)
}

#sample_type ANOVA
MyAnova <- function(gene){
  bartlett.test(data[[gene]] ~ sample_type, data = data)#p值>0.05，认为各组的数据是等方差的,这里不等，怎么办？
  anova_tmp <- ifelse(bartlett.test(data[[gene]] ~ sample_type, data = data)$p.value>=0.05,'TRUE','FALSE')
  print(paste0('Is var of these groups equal? :',anova_tmp))
  myaov <- aov(data[[gene]] ~ sample_type,data=data)
  summary(myaov)
  pvalue_ANOVA <- summary(myaov)[[1]][["Pr(>F)"]][[1]]
  pvalue_ANOVA <- format(pvalue_ANOVA,scientific = F)
  a <- plotmeans(data[[gene]] ~ data$sample_type,xlab="sample_type",
            ylab=gene,main="Mean Plot\n with 95%CI")+
    text(x= 1.1, y= 9, labels=paste0('pvalue=',pvalue_ANOVA))
  print(a)
  b <- boxplot(data[[gene]]~data$sample_type,data = data,xlab='Sample Type',ylab=gene,
          main='Sample Type_ANOVA')
  text(x= 1.5, y= 2, labels=paste0('pvalue=',pvalue_ANOVA))
}



pdf('sample_type_Ttest.pdf',width = 15,height = 10,onefile = T)
for (i in up_gene) {
  print(paste0('Now processing: ',i))
  data <- get_data(i)
  length(levels(data$sample_type))
  print(paste0('Is it right to use Ttest here:',isTRUE(length(levels(data$sample_type))<=2)))
  #2个用ttest，3个及以上用anova
  sampleplot <- MyTtest(i)
  print(sampleplot)
}
dev.off()

# Mon Nov 05 17:36:58 2018 ------------------------------


