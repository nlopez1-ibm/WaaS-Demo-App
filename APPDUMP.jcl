//IBMUSERG JOB 'ACCT#',MSGCLASS=H,REGION=0M,MSGLEVEL=(1,1)
//*   Dec'2023 refac
//*
//*   Application runtime replication job (DUMP) by Nelson Lopez
//* Submit this job on a Dev LPAR to DUMP a Team's runtime datasets.
//* The Dumps are compressed and pushed to Git.  The job APPREST.jcl,
//* is executed on a virtual zOS(WaaS VSI) to restore the dumps.
//*
//* Datasets to be dumped are defined in the COPY step below. This
//* example DUMPs the following dataset types of a sample demo app:
//*  1: DD=APPLIBS - an application's team and user libs
//*  2: DD=SYSLIBS - system libs like joblibs, cntl, procs, ...
//*  3: DD=CSDOUT  - CICS definitions for a sample app
//*
//* TODO Change/review the following before running this job:
//*  + Jobcard, space parms, HLQ, USS home dir.
//*  + The DUMP control cards
//*  + The CICSEXTR step's SYSIN to extract CICS defintions
//*  + Add you remote git repo name to the CLIGIT step.
//*
//* NOTE: to test a CICS app, RPL libs must be DUMPED and added
//* to the sample CICSTSXX.jcl file in this repo. It will be used
//* to replace and restart the CICSTSXX STC in the new zOS.
//****
//*
//* Change these symbolics to match your DEV LPAR.
//*
//USSHOME SET HOME='/u/ibmuser/App-IaC'
//HLQ     SET HLQ='IBMUSER'
//*
//* Remove old files if they are there
//*
//DELXMIT  EXEC PGM=BPXBATCH,PARM='sh mkdir -p &HOME ; rm &HOME/*'
//STDOUT   DD  SYSOUT=*
//STDERR   DD  SYSOUT=*
//DELDEFS  DD  DISP=(MOD,DELETE),DSN=&HLQ..WAZI.CICS.APPDEFS,
// SPACE=(TRK,(1,0)),UNIT=SYSDA
//DELAPPS  DD  DISP=(MOD,DELETE),DSN=&HLQ..WAZI.DUMP.APPLIBS,
// SPACE=(TRK,(1,0)),UNIT=SYSDA
//DELSYS   DD  DISP=(MOD,DELETE),DSN=&HLQ..WAZI.DUMP.SYSLIBS,
// SPACE=(TRK,(1,0)),UNIT=SYSDA
//DELAPPC  DD  DISP=(MOD,DELETE),DSN=&HLQ..WAZI.DUMP.APPLIBS.COMP,
// SPACE=(TRK,(1,0)),UNIT=SYSDA
//DELSYSC  DD  DISP=(MOD,DELETE),DSN=&HLQ..WAZI.DUMP.SYSLIBS.COMP,
// SPACE=(TRK,(1,0)),UNIT=SYSDA
//*
//** Dump datasets - review the space parm and cntl
//*
//COPY     EXEC PGM=ADRDSSU
//APPLIBS  DD  DISP=(NEW,CATLG),DSN=&HLQ..WAZI.DUMP.APPLIBS,
// DCB=(RECFM=U,DSORG=PS,LRECL=0,BLKSIZE=0),SPACE=(CYL,(1,25)),
// UNIT=SYSDA
//SYSLIBS  DD  DISP=(NEW,CATLG),DSN=&HLQ..WAZI.DUMP.SYSLIBS,
// DCB=(RECFM=U,DSORG=PS,LRECL=0,BLKSIZE=0),SPACE=(CYL,(1,25)),
// UNIT=SYSDA
//SYSPRINT DD SYSOUT=*
//*
//* Add your Team and/or personal PDSs in the first INCLUDE block.
//* The second block is for any system libs.
//*
//SYSIN    DD *
 DUMP DATASET (INCLUDE( -
                ZDEV.FEATURE.**, -
                ZDEV.DEVELOP.**, -
                DAT.**, -
                NLOPEZ.DAT.**, -
                NLOPEZ.IDZ.**) -
               BY(DSORG,EQ,(SAM,PDS,PDSE)) ) OUTDD(APPLIBS) TOL(ENQF)

  DUMP DATASET (INCLUDE( -
                 ZDEV.MAIN.**, -
                 DAT.PROD.**) -
               BY(DSORG,EQ,(SAM,PDS,PDSE)) ) OUTDD(SYSLIBS) TOL(ENQF)
/*
//*
//* Compress the dumps (over 50% reduction!)
//*
//COMPAPP  EXEC PGM=AMATERSE,PARM=SPACK
//SYSPRINT DD SYSOUT=*
//SYSUT1   DD DISP=SHR,DSN=&HLQ..WAZI.DUMP.APPLIBS
//SYSUT2   DD  DISP=(NEW,CATLG),DSN=&HLQ..WAZI.DUMP.APPLIBS.COMP,
// DCB=(RECFM=F,DSORG=PS,LRECL=0,BLKSIZE=0),SPACE=(CYL,(1,25),RLSE),
// UNIT=SYSDA
//*
//COMPSYS  EXEC PGM=AMATERSE,PARM=SPACK
//SYSPRINT DD SYSOUT=*
//SYSUT1   DD DISP=SHR,DSN=&HLQ..WAZI.DUMP.SYSLIBS
//SYSUT2   DD  DISP=(NEW,CATLG),DSN=&HLQ..WAZI.DUMP.SYSLIBS.COMP,
// DCB=(RECFM=F,DSORG=PS,LRECL=0,BLKSIZE=0),SPACE=(CYL,(1,25),RLSE),
// UNIT=SYSDA
//*
//* Convert the dumps to XMIT format and store them in USS.
//* This assumes the USS HOME dir has enough free space.
//*
//XMIT EXEC PGM=IKJEFT01
//IAPPLIBS    DD DSN=&HLQ..WAZI.DUMP.APPLIBS.COMP,DISP=OLD
//OAPPLIBS    DD PATH='&HOME/applibs.xmit',
//            PATHDISP=(KEEP,DELETE),
//            PATHOPTS=(OWRONLY,OCREAT,OEXCL),PATHMODE=(SIRUSR,SIWUSR)
//ISYSLIBS    DD DSN=&HLQ..WAZI.DUMP.SYSLIBS.COMP,DISP=OLD
//OSYSLIBS    DD PATH='&HOME/syslibs.xmit',
//            PATHDISP=(KEEP,DELETE),
//            PATHOPTS=(OWRONLY,OCREAT,OEXCL),PATHMODE=(SIRUSR,SIWUSR)
//SYSTSPRT DD SYSOUT=*
//SYSTSIN  DD *
 XMIT SOW1.IBMUSER FILE(IAPPLIBS) OUTFILE(OAPPLIBS)
 XMIT SOW1.IBMUSER FILE(ISYSLIBS) OUTFILE(OSYSLIBS)
/*
//* Extract your application CICS defintions.
//* Ensure the CICS steplib and CSD DSNs match your CICS region.
//* Also add your CICS application Group name(s) for the extract.
//*
//CICSEXTR EXEC PGM=DFHCSDUP,REGION=0M,
//         PARM='CSD(READWRITE),PAGESIZE(60),NOCOMPAT'
//STEPLIB  DD DISP=SHR,DSN=CICSTS.V6R1M0.CICS.SDFHLOAD
//DFHCSD   DD DISP=SHR,DSN=CICSTS61.DFHCSD
//SYSPRINT DD SYSOUT=*
//CSDOUT   DD DISP=(NEW,CATLG),DSN=&HLQ..WAZI.CICS.APPDEFS,
//         LRECL=80,RECFM=FB,BLKSIZE=80,SPACE=(TRK,(1,1)),UNIT=SYSDA
//*
//* Dump Nelsons Demo App poc-workspace
//* Chg the GROUP. More than one EXTRACT can be performed.
//*
//SYSIN    DD  *
 EXTRACT GROUP(DAT) OBJECTS USERPROGRAM(DFH0CBDC)
/*
//*
//* copy the cics def file to USS
//*
//COPYDEFS EXEC PGM=BPXBATCH,
// PARM=('sh cp //"''&HLQ..WAZI.CICS.APPDEFS''" &HOME/CICSDEF.cntl')
//STDOUT   DD  SYSOUT=*
//STDERR   DD  SYSOUT=*
//*
//* Git Phase: Push USS files to a Git Repo.
//*  Assumes a git remote repo exists and git is installed on USS.
//*  Chg the repo name and access key to match your config.
//*
//* NOTE DEC 2023 - major restructure of repo and tags ... untested...
//GITCLI      EXEC PGM=BPXBATCH,REGION=0M
//STDOUT   DD   SYSOUT=*
//STDERR   DD   SYSOUT=*
//STDPARM  DD   *
SH git --version; pwd ; rm -fr git_tmp; mkdir git_tmp; cd git_tmp ;
 export r=WaaS-Demo-App.git ;
 export p=ghp_mV70mLZbjc4bApO4ES5 ;
 export t=Pr41113NFXr3Os0k7 ;
 git clone https://oauth2:$p$t@github.com/nlopez1-ibm/$r ;
 cd  WaaS-DemoApp-IAC  ;
 cp  ~/App-IaC/* . ; chtag -b *.xmit ; ls -lasT ;
 git add . ;
 git commit -m "Refresh images. Job=APPDUMP, USER=$LOGNAME, SYS=$(uname -Ia)";
 git push ; git log -n 1
/*
