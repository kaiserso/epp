##############################################################################
###                                                                        ###
###  Example of fitting EPP r-spline and r-trend model to data from        ###
###  to data from Botswana.                                                ###
###                                                                        ###
###  Created on 19 June 2015 by Jeff Eaton (jeffrey.eaton@imperial.ac.uk)  ###
###                                                                        ###
##############################################################################

setwd("~/Documents/Code/R/epp/")

## library(epp)
devtools::load_all("~/Documents/Code/R/epp/")


## Read Botswana data and prepare fit (available for download: http://apps.unaids.org/spectrum/)

## bw.path <- "~/Documents/Data/Spectrum files/2014, final (downloaded 8 October 2014)/Botswana 2014/Botswana 2014_Nat 19_06_14-c"

bw.path <- "~/Documents/Data/Spectrum files/2016 final/SSA/Botswana_ Final_15_04_ 2016 upd.PJNZ"

bw.out <- prepare_epp_fit(bw.path, proj.end=2017.5)


#########################
####  Run EPP model  ####
#########################

## r-spline model: fixed parameter values
theta.rspline <- c(2.16003605, -0.76713859, 0.21682066, 0.03286402, 0.21494412,
                   0.40138627, -0.08235464, -16.32721684, -2.97511957,
                   0.21625028, -4.199)

fp <- attr(bw.out$Urban, "eppfp")
fp$ancrtsite.beta <- 0

param <- fnCreateParam(theta.rspline, fp)
fp.rspline <- update(fp, list=param)
mod.rspline <- simmod(fp.rspline)



round(prev(mod.rspline), 3)               # prevalence
round(incid(mod.rspline, fp.rspline), 4)  # incidence

likdat <- fnCreateLikDat(attr(bw.out$Urban, "eppd"), 1970L)
qM <- qnorm(prev(mod.rspline))                              # probit-tranformed prevalence
log(anclik::fnANClik(qM + fp.rspline$ancbias, likdat$anclik.dat, exp(theta.rspline[11])))   # ANC likelihood
epp:::fnHHSll(qM, likdat$hhslik.dat)                              # survey likelihood
ll(theta.rspline, fp.rspline, likdat)


## r-trend model: fixed parameter values
fp <- update(attr(bw.out$Urban, "eppfp"), eppmod = "rtrend", iota = 0.0025)
theta.rtrend <- c(1978, 20, 0.42, 0.46, 0.17, -0.68, -0.038, 0.21625028, -4.199)

param.rtrend <- fnCreateParam(theta.rtrend, fp)
fp.rtrend <- update(fp, list=param.rtrend)
mod.rtrend <- simmod(fp.rtrend)

round(prev(mod.rtrend), 3)              # prevalence
round(incid(mod.rtrend, fp.rtrend), 4)  # incidence

qM <- qnorm(prev(mod.rtrend))                             # probit-tranformed prevalence
log(anclik::fnANClik(qM + fp.rtrend$ancbias, likdat$anclik.dat, exp(theta.rtrend[9])))  # ANC likelihood
epp:::fnHHSll(qM, likdat$hhslik.dat)                             # survey likelihood
ll(theta.rtrend, fp.rtrend, likdat)


#########################
####  Fit EPP model  ####
#########################

## Note: This crashes if there are fewer than two parameter combinations
##       with non-zero likelihood. In this case run again with different
##       seed, or larger B0.

bw.rspline <- list()
bw.rspline$Urban <- fitmod(bw.out$Urban, equil.rprior=TRUE, B0=1e4, B=1e3, D=3, opt_iter=4)
bw.rspline$Rural <- fitmod(bw.out$Rural, equil.rprior=TRUE, B0=1e4, B=1e3, D=3, opt_iter=4)

bw.rtrend <- list()
bw.rtrend$Urban <- fitmod(bw.out$Urban, eppmod="rtrend", iota=0.0025, B0=1e4, B=1e3, D=3, opt_iter=4)
bw.rtrend$Rural <- fitmod(bw.out$Rural, eppmod="rtrend", iota=0.0025, B0=1e4, B=1e3, D=3, opt_iter=4)

save(bw.out, bw.rspline, bw.rtrend, file="bw-example-fit.RData")


######################################
####  Simulate posterior outputs  ####
######################################


bw.rspline$Urban <- simfit(bw.rspline$Urban)
bw.rspline$Rural <- simfit(bw.rspline$Rural)

bw.rtrend$Urban <- simfit(bw.rtrend$Urban)
bw.rtrend$Rural <- simfit(bw.rtrend$Rural)

  
## Plot prevalence, incidence, r(t)
cred.region <- function(x, y, ...)
  polygon(c(x, rev(x)), c(y[1,], rev(y[2,])), border=NA, ...)

transp <- function(col, alpha=0.5)
  return(apply(col2rgb(col), 2, function(c) rgb(c[1]/255, c[2]/255, c[3]/255, alpha)))

plot.prev <- function(fit, ylim=c(0, 0.22), col="blue"){
  plot(1970:2015, rowMeans(fit$prev), type="n", ylim=ylim, ylab="", yaxt="n", xaxt="n")
  axis(1, labels=FALSE)
  axis(2, labels=FALSE)
  cred.region(1970:2015, apply(fit$prev, 1, quantile, c(0.025, 0.975)), col=transp(col, 0.3))
  lines(1970:2015, rowMeans(fit$prev), col=col)
  ##
  points(fit$likdat$hhslik.dat$year, fit$likdat$hhslik.dat$prev, pch=20)
  segments(fit$likdat$hhslik.dat$year,
           y0=pnorm(fit$likdat$hhslik.dat$W.hhs - qnorm(0.975)*fit$likdat$hhslik.dat$sd.W.hhs),
           y1=pnorm(fit$likdat$hhslik.dat$W.hhs + qnorm(0.975)*fit$likdat$hhslik.dat$sd.W.hhs))
}

plot.incid <- function(fit, ylim=c(0, 0.05), col="blue"){
  plot(1970:2015, rowMeans(fit$incid), type="n", ylim=ylim, ylab="", yaxt="n", xaxt="n")
  axis(1, labels=FALSE)
  axis(2, labels=FALSE)
  cred.region(1970:2015, apply(fit$incid, 1, quantile, c(0.025, 0.975)), col=transp(col, 0.3))
  lines(1970:2015, rowMeans(fit$incid), col=col)
}

plot.rvec <- function(fit, ylim=c(0, 3), col="blue"){
  rvec <- mapply(function(rv, par){replace(rv, fit$fp$proj.steps < par$tsEpidemicStart, NA)},
                 data.frame(fit$rvec), fit$param)
  plot(fit$fp$proj.steps, rowMeans(rvec, na.rm=TRUE), type="n", ylim=ylim, ylab="", yaxt="n")
  axis(2, labels=FALSE)
  cred.region(fit$fp$proj.steps, apply(rvec, 1, quantile, c(0.025, 0.975), na.rm=TRUE), col=transp(col, 0.3))
  lines(fit$fp$proj.steps, rowMeans(rvec, na.rm=TRUE), col=col)
}

## Plot Botswana Urban
quartz(h=3.6, w=6, pointsize=8)

par(mfrow=c(2,3), tcl=-0.25, mgp=c(2, 0.5, 0), mar=c(2, 3.5, 2, 1), las=1, cex=1.0)
##
plot.prev(bw.rspline$Urban, col="darkred", ylim=c(0, 0.3))
axis(2, tick="no")
axis(1, tick="no")
mtext("prevalence", 2, 2.5, las=3)
mtext("Botswana Urban: r-spline", line=0.5, at=1955, adj=0, font=2, cex=1.2)
##
plot.incid(bw.rspline$Urban, col="darkred", ylim=c(0, 0.06))
axis(2, tick="no")
axis(1, tick="no")
mtext("incidence", 2, 2.5, las=3)
##
plot.rvec(bw.rspline$Urban, col="darkred")
axis(2, tick="no")
axis(1, tick="no")
mtext("r(t)", 2, 2.5, las=3)
####
plot.prev(bw.rtrend$Urban, col="darkolivegreen", ylim=c(0, 0.3))
axis(2, tick="no")
axis(1, tick="no")
mtext("prevalence", 2, 2.5, las=3)
mtext("Botswana Urban: r-trend", line=0.5, at=1955, adj=0, font=2, cex=1.2)
##
plot.incid(bw.rtrend$Urban, col="darkolivegreen", ylim=c(0, 0.06))
axis(2, tick="no")
axis(1, tick="no")
mtext("incidence", 2, 2.5, las=3)
##
plot.rvec(bw.rtrend$Urban, col="darkolivegreen")
axis(2, tick="no")
axis(1, tick="no")
mtext("r(t)", 2, 2.5, las=3)


## Plot Botswana Rural
quartz(h=3.6, w=6, pointsize=8)

par(mfrow=c(2,3), tcl=-0.25, mgp=c(2, 0.5, 0), mar=c(2, 3.5, 2, 1), las=1, cex=1.0)
##
plot.prev(bw.rspline$Rural, col="darkred", ylim=c(0, 0.3))
axis(2, tick="no")
axis(1, tick="no")
mtext("prevalence", 2, 2.5, las=3)
mtext("Botswana Rural: r-spline", line=0.5, at=1955, adj=0, font=2, cex=1.2)
##
plot.incid(bw.rspline$Rural, col="darkred", ylim=c(0, 0.06))
axis(2, tick="no")
axis(1, tick="no")
mtext("incidence", 2, 2.5, las=3)
##
plot.rvec(bw.rspline$Rural, col="darkred")
axis(2, tick="no")
axis(1, tick="no")
mtext("r(t)", 2, 2.5, las=3)
####
plot.prev(bw.rtrend$Rural, col="darkolivegreen", ylim=c(0, 0.3))
axis(2, tick="no")
axis(1, tick="no")
mtext("prevalence", 2, 2.5, las=3)
mtext("Botswana Rural: r-trend", line=0.5, at=1955, adj=0, font=2, cex=1.2)
##
plot.incid(bw.rtrend$Rural, col="darkolivegreen", ylim=c(0, 0.06))
axis(2, tick="no")
axis(1, tick="no")
mtext("incidence", 2, 2.5, las=3)
##
plot.rvec(bw.rtrend$Rural, col="darkolivegreen")
axis(2, tick="no")
axis(1, tick="no")
mtext("r(t)", 2, 2.5, las=3)


##########################################################
####  Simulate ANC posterior predictive distribution  ####
##########################################################

add.b.site <- function(fit){
  qM.mat <- sweep(qnorm(fit$prev), 2, sapply(fit$param, "[[", "ancbias"), "+")
  fit$b.site <- apply(qM.mat, 2, anclik::sample.b.site, fit$likdat$anclik.dat)
  return(fit)
}

add.pred.site <- function(fit){
  qM.mat <- sweep(qnorm(fit$prev), 2, sapply(fit$param, "[[", "ancbias"), "+")
  fit$pred.site <- lapply(seq(along=fit$param), function(ii) anclik::sample.pred.site(qM.mat[,ii], fit$b.site[,ii], fit$likdat$anclik.dat))
  return(fit)
}

pred.coverage <- function(fit){
  pred.quant <- apply(sapply(fit$pred.site, unlist), 1, quantile, c(0.025, 0.975))
  obs <- pnorm(unlist(fit$likdat$anclik.dat$W.lst))
  return(mean(obs > pred.quant[1,] & obs < pred.quant[2,]))
}

pred.quantile <- function(fit){
  pred.mat <- sapply(fit$pred.site, unlist)
  obs <- pnorm(unlist(fit$likdat$anclik.dat$W.lst))
  pred.quant <- sapply(seq_along(obs), function(i) ecdf(pred.mat[i,])(obs[i]))
  fit$pred.quant <- split(pred.quant, rep(names(fit$likdat$anclik.dat$W.lst), sapply(fit$likdat$anclik.dat$W.lst, length)))
  return(fit)
}

## Sample site-level random effects
bw.rspline$Urban <- add.b.site(bw.rspline$Urban)
bw.rspline$Rural <- add.b.site(bw.rspline$Rural)
bw.rtrend$Urban <- add.b.site(bw.rtrend$Urban)
bw.rtrend$Rural <- add.b.site(bw.rtrend$Rural)

## Sample from clinic posterior predictive distribution
bw.rspline$Urban <- add.pred.site(bw.rspline$Urban)
bw.rspline$Rural <- add.pred.site(bw.rspline$Rural)
bw.rtrend$Urban <- add.pred.site(bw.rtrend$Urban)
bw.rtrend$Rural <- add.pred.site(bw.rtrend$Rural)

## In-sample coverage of 95% prediction interval
pred.coverage(bw.rspline$Urban)
pred.coverage(bw.rspline$Rural)
pred.coverage(bw.rtrend$Urban)
pred.coverage(bw.rtrend$Rural)

## Q-Q plot of predicted vs. theoretical quantiles for ANC prevalence
bw.rspline$Urban <- pred.quantile(bw.rspline$Urban)
bw.rspline$Rural <- pred.quantile(bw.rspline$Rural)
bw.rtrend$Urban <- pred.quantile(bw.rtrend$Urban)
bw.rtrend$Rural <- pred.quantile(bw.rtrend$Rural)

quartz(w=6, h=3, pointsize=9)

par(mfrow=c(1,2), tcl=-0.25, mgp=c(2, 0.5, 0), mar=c(3, 3, 2.5, 1), las=1, cex=1.0)
##
matplot(seq(0, 1, length.out=length(unlist(bw.rspline$Urban$pred.quant))),
     cbind(sort(unlist(bw.rspline$Urban$pred.quant)),
           sort(unlist(bw.rtrend$Urban$pred.quant))),
     pch=20, cex=0.5, col=c("darkred", "darkolivegreen"),
     main="Botswana Urban",
     xlab="Theoretical quantiles",
     ylab="Observed quantiles")
abline(a=0, b=1)
legend("topleft", c("r-spline", "r-trend"), pch=20, pt.cex=0.5, col=c("darkred", "darkolivegreen"))
##
matplot(seq(0, 1, length.out=length(unlist(bw.rspline$Rural$pred.quant))),
        cbind(sort(unlist(bw.rspline$Rural$pred.quant)),
              sort(unlist(bw.rtrend$Rural$pred.quant))),
     pch=20, cex=0.5, col=c("darkred", "darkolivegreen"),
     main="Botswana Rural",
     xlab="Theoretical quantiles",
     ylab="Observed quantiles")
abline(a=0, b=1)
legend("topleft", c("r-spline", "r-trend"), pch=20, pt.cex=0.5, col=c("darkred", "darkolivegreen"))


###################################################################
####  Compare random-walk projection with r-spline projection  ####
###################################################################

bw.rwproj <- list()
bw.rwproj$Urban <- simfit(bw.rspline$Urban, rwproj=TRUE)
bw.rwproj$Rural <- simfit(bw.rspline$Rural, rwproj=TRUE)



quartz(h=3.6, w=6, pointsize=8)

par(mfrow=c(2,3), tcl=-0.25, mgp=c(2.6, 0.5, 0), mar=c(2, 3.5, 2, 1), las=1, cex=1.0)
##
plot(2005:2015, rowMeans(bw.rspline$Urban$prev)[36:46], type="n", ylim=c(0.15, 0.3), ylab="prevalence")
cred.region(2005:2015, apply(bw.rspline$Urban$prev[36:46,], 1, quantile, c(0.025, 0.975)), col=transp("blue", 0.3))
cred.region(2005:2015, apply(bw.rwproj$Urban$prev[36:46,], 1, quantile, c(0.025, 0.975)), col=transp("darkolivegreen", 0.3))
matlines(2005:2015, cbind(rowMeans(bw.rspline$Urban$prev[36:46,]), rowMeans(bw.rwproj$Urban$prev[36:46,])), lty=1, lwd=2, col=c("blue", "darkolivegreen"))
legend("topright", legend=c("rspline", "rw"), lwd=2, col=c("blue", "darkolivegreen"))
mtext("Botswana Urban", line=0.5, at=2002, adj=0, font=2, cex=1.2)
##
plot(2005:2015, rowMeans(bw.rspline$Urban$incid)[36:46], type="n", ylim=c(0.0, 0.02), ylab="incidence")
cred.region(2005:2015, apply(bw.rspline$Urban$incid[36:46,], 1, quantile, c(0.025, 0.975)), col=transp("blue", 0.3))
cred.region(2005:2015, apply(bw.rwproj$Urban$incid[36:46,], 1, quantile, c(0.025, 0.975)), col=transp("darkolivegreen", 0.3))
matlines(2005:2015, cbind(rowMeans(bw.rspline$Urban$incid[36:46,]), rowMeans(bw.rwproj$Urban$incid[36:46,])), lty=1, lwd=2, col=c("blue", "darkolivegreen"))
legend("topright", legend=c("rspline", "rw"), lwd=2, col=c("blue", "darkolivegreen"))
##
plot(seq(2005.5, 2015.5, 0.1), rowMeans(bw.rspline$Urban$rvec)[351:451], type="n", ylim=c(0.03, 0.18), ylab="r(t)")
cred.region(seq(2005.5, 2015.5, 0.1), apply(bw.rspline$Urban$rvec[351:451,], 1, quantile, c(0.025, 0.975)), col=transp("blue", 0.3))
cred.region(seq(2005.5, 2015.5, 0.1), apply(bw.rwproj$Urban$rvec[351:451,], 1, quantile, c(0.025, 0.975)), col=transp("darkolivegreen", 0.3))
matlines(seq(2005.5, 2015.5, 0.1), cbind(rowMeans(bw.rspline$Urban$rvec[351:451,]), rowMeans(bw.rwproj$Urban$rvec[351:451,])), lty=1, lwd=2, col=c("blue", "darkolivegreen"))
legend("topleft", legend=c("rspline", "rw"), lwd=2, col=c("blue", "darkolivegreen"))
####
####
plot(2005:2015, rowMeans(bw.rspline$Rural$prev)[36:46], type="n", ylim=c(0.15, 0.3), ylab="prevalence")
cred.region(2005:2015, apply(bw.rspline$Rural$prev[36:46,], 1, quantile, c(0.025, 0.975)), col=transp("blue", 0.3))
cred.region(2005:2015, apply(bw.rwproj$Rural$prev[36:46,], 1, quantile, c(0.025, 0.975)), col=transp("darkolivegreen", 0.3))
matlines(2005:2015, cbind(rowMeans(bw.rspline$Rural$prev[36:46,]), rowMeans(bw.rwproj$Rural$prev[36:46,])), lty=1, lwd=2, col=c("blue", "darkolivegreen"))
legend("topright", legend=c("rspline", "rw"), lwd=2, col=c("blue", "darkolivegreen"))
mtext("Botswana Rural", line=0.5, at=2002, adj=0, font=2, cex=1.2)
##
plot(2005:2015, rowMeans(bw.rspline$Rural$incid)[36:46], type="n", ylim=c(0.0, 0.02), ylab="incidence")
cred.region(2005:2015, apply(bw.rspline$Rural$incid[36:46,], 1, quantile, c(0.025, 0.975)), col=transp("blue", 0.3))
cred.region(2005:2015, apply(bw.rwproj$Rural$incid[36:46,], 1, quantile, c(0.025, 0.975)), col=transp("darkolivegreen", 0.3))
matlines(2005:2015, cbind(rowMeans(bw.rspline$Rural$incid[36:46,]), rowMeans(bw.rwproj$Rural$incid[36:46,])), lty=1, lwd=2, col=c("blue", "darkolivegreen"))
legend("topright", legend=c("rspline", "rw"), lwd=2, col=c("blue", "darkolivegreen"))
##
plot(seq(2005.5, 2015.5, 0.1), rowMeans(bw.rspline$Rural$rvec)[351:451], type="n", ylim=c(0.03, 0.18), ylab="r(t)")
cred.region(seq(2005.5, 2015.5, 0.1), apply(bw.rspline$Rural$rvec[351:451,], 1, quantile, c(0.025, 0.975)), col=transp("blue", 0.3))
cred.region(seq(2005.5, 2015.5, 0.1), apply(bw.rwproj$Rural$rvec[351:451,], 1, quantile, c(0.025, 0.975)), col=transp("darkolivegreen", 0.3))
matlines(seq(2005.5, 2015.5, 0.1), cbind(rowMeans(bw.rspline$Rural$rvec[351:451,]), rowMeans(bw.rwproj$Rural$rvec[351:451,])), lty=1, lwd=2, col=c("blue", "darkolivegreen"))
legend("topleft", legend=c("rspline", "rw"), lwd=2, col=c("blue", "darkolivegreen"))
