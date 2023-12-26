//*********************************************************************
//*                                                                   *
//*                                                                   *
//*                                                                   *
//*     Licensed Materials - Property of IBM                          *
//*                                                                   *
//*     5655-YA1                                                      *
//*                                                                   *
//*     (C) Copyright IBM Corp. 1991, 2016 All Rights Reserved.       *
//*                                                                   *
//*                                                                   *
//*                                                                   *
//*                                                                   *
//* STATUS = 7.4.0                                                    *
//*                                                                   *
//* CHANGE ACTIVITY :                                                 *
//*                                                                   *
//*   $MOD(DFHSTART),COMP(INSTALL),PROD(CICS    ):                    *
//*                                                                   *
//*  PN= REASON REL YYMMDD HDXXIII : REMARKS                          *
//* $01= A29022 650 070221 HD4PALS : Migrate PK29022 from SPA R640    *
//* $L0= Base   321 91     HD3SCWG : Base                             *
//* $L1= 839    630 030619 HDCQMDB : Convert JVM launcher and DTC to  *
//* $L2= 852    640 040813 HD3SCWG : Add MQ library SCSQLOAD          *
//* $L3= 852    640 040918 HD3SCWG : Add SCSQANLE  SCSQCICS  SCSQAUTH *
//* $L4= 807    650 051101 HD3SCWG : Add SEYUAUTH to STEPLIB          *
//* $L5= R18731 670 100902 HDAFDRB : Update REG setting               *
//* $L6= R00114 670 101118 HD3SCWG : Default REG to 1150M + MEMLIMIT  *
//* $P1= D06371 630 030321 HDFVGMB : Pull DFHSTART parms and DOCS int *
//* $P2= D07561 630 030516 HDCQMDB : Remove references to DFHJVM      *
//* $P3= D08500 630 030723 HDCQMDB : XPLink library changes           *
//* $P4= D09282 630 031006 HD3SCWG : Increase region size to 64M      *
//* $P5= D18467 650 070417 HD3SCWG : Remove SEYUAUTH                  *
//* $P6= D25567 660 090330 HD4IAEC : Update GCD AMP BUFSP             *
//*      D51430 680 120514 HDIDNCS : MEMLIMIT to 8G                   *
//*      D41652 680 120614 HDJYISB : Add USSHOME + CICSSVC            *
//*      D73969 690 130805 HDJBAPC : Added CPSM Library               *
//*      R77578 690 140228 HDDLCRP : Activation Module                *
//*     R113443 710 161202 HD2GJST : MEMLIMIT to 10G                  *
//*     R148165 720 180409 HDLXDR  : Remove SDFJAUTH                  *
//*     D150530 720 180724 HD2GJST : Update comments                  *
//*                                                                   *
//*********************************************************************
//DFHSTART PROC START='AUTO',
// INDEX1='CICSTS61',
// INDEX2='CICSTS.V6R1M0.CICS',
// INDEX3='CICSTS.V6R1M0.CPSM',
// INDEX4='CICSTS.V6R1M0',
// ACTIVATE=SDFHLIC,                                     @D77578A
// REGNAM='',
// REG=0M,
// MEMLIM='10G',                                        @R113443C
// DUMPTR='YES',
// RUNCICS='YES',
// OUTC='*',
// SIP=1,
// CICSSVC='216',
// USSHOME='/usr/lpp/cicsts'
//*
//*    INDEX1 - HIGH-LEVEL QUALIFIER(S) OF CICS RUN TIME DATASETS
//*    INDEX2 - HIGH-LEVEL QUALIFIER(S) OF CICS LOAD LIBRARIES
//*    INDEX3 - HIGH-LEVEL QUALIFIER(S) OF CPSM LOAD LIBRARIES
//*    INDEX4 - HIGH-LEVEL QUALIFIER(S) OF ACTIVATION LIBRARY
//*    ACTIVATE - ACTIVATION PRODUCT (SDFHLIC, SDFHVUE or SDFHDEV)
//*    REGNAM - REGION NAME FOR SINGLE OR MRO REGION
//*       REG - MVS REGION STORAGE REQUIRED
//*    MEMLIM - MEMORY LIMIT
//*     START - TYPE OF CICS START-UP REQUIRED
//*    DUMPTR - DUMP/TRACE ANALYSIS REQUIRED, YES OR NO
//*   RUNCICS - CICS STARTUP REQUIRED, YES OR NO
//*      OUTC - PRINT OUTPUT CLASS
//*       SIP - SUFFIX OF DFH$SIP MEMBER IN THE SYSIN DATASET
//*   CICSSVC - SVC NUMBER FOR CICS DFHCSVC
//*   USSHOME - FULL USS PATH FOR THE CICS INSTALLATION ON HFS
//*
//* SET THE RETURN CODE TO CONTROL IF CICS SHOULD BE
//* STARTED OR NOT
//CICSCNTL EXEC PGM=IDCAMS,REGION=1M
//SYSPRINT DD SYSOUT=*
//SYSIN    DD DISP=SHR,
// DSN=&INDEX1..SYSIN(DFHRC&RUNCICS)
//*
//* SET THE RETURN CODE TO CONTROL THE DUMP AND TRACE
//* ANALYSIS STEPS
//DTCNTL   EXEC PGM=IDCAMS,REGION=1M
//SYSPRINT DD SYSOUT=*
//SYSIN    DD DISP=SHR,
// DSN=&INDEX1..SYSIN(DFHRC&DUMPTR)
//*
//***********************************************************
//*******************  EXECUTE CICS  ************************
//***********************************************************
//CICS    EXEC PGM=DFHSIP,REGION=&REG,TIME=1440,
// MEMLIMIT=&MEMLIM,                                         @L6A
// COND=(1,NE,CICSCNTL),
// PARM=('SYSIN','START=&START','CICSSVC=&CICSSVC',
// 'USSHOME=&USSHOME')
//*
//*            THE CAVM DATASETS - XRF
//*
//* THE "FILEA" APPLICATIONS SAMPLE VSAM FILE
//* (THE FILEA DD STATEMENT BELOW WILL
//* OVERRIDE THE CSD DEFINITION IN GROUP DFHMROFD)
//FILEA    DD DISP=SHR,
// DSN=&INDEX1..CICS&REGNAM..FILEA
//*
//SYSIN    DD DISP=SHR,
// DSN=&INDEX1..SYSIN(DFH$SIP&SIP)
//DFHCMACD DD DSN=CICSTS61.DFHCMACD,DISP=SHR
//***********************************************************
//*        THE CICS STEPLIB CONCATENATION
//*        If Language Environment is required, the SCEERUN2
//*        and SCEERUN datasets are needed in STEPLIB or LNKLST
//***********************************************************
//STEPLIB  DD DSN=&INDEX3..SEYUAUTH,DISP=SHR           @D73969A
//         DD DSN=&INDEX2..SDFHAUTH,DISP=SHR
//         DD DSN=&INDEX4..&ACTIVATE,DISP=SHR          @R77578A
//*        DD DSN=CEE.SCEERUN2,DISP=SHR
//*        DD DSN=CEE.SCEERUN,DISP=SHR
//***********************************************************
//*        THE CICS LIBRARY (DFHRPL) CONCATENATION
//*        If Language Environment is required, the SCEECICS,
//*        SCEERUN2 and SCEERUN datasets are needed in DFHRPL.
//*
//*        If you are using MQ as the transport mechanism
//*        for SIBus uncomment the DD statements for the
//*        SCSQLOAD, SCSQANLE, SCSQCICS and SCSQAUTH datasets.
//***********************************************************
//*  Begin Ansible DB2 Block Insert
//         DD DSN=DB2.V13R1M0.SDSNLOAD,DISP=SHR
//         DD DSN=DB2.V13R1M0.SDSNLOD2,DISP=SHR
//*  End Ansible DB2 Block Insert
//DFHRPL   DD DSN=&INDEX3..SEYULOAD,DISP=SHR           @D73969A
//         DD DSN=&INDEX2..SDFHLOAD,DISP=SHR
//*  NJL-v5 -myApp RPLs for testing  Dev and Prod loadlibs
//         DD DISP=SHR,DSN=ZDEV.MAIN.CICSLOAD  UCD DAT0
//         DD DISP=SHR,DSN=ZDEV.MAIN.LOAD
//*  Begin Ansible 1st Insert Block  *//
//         DD DSN=BZU.SBZULOAD,DISP=SHR
//         DD DSN=FEL.SFELLOAD,DISP=SHR
//         DD DSN=CEE.SCEECICS,DISP=SHR
//         DD DSN=CEE.SCEERUN2,DISP=SHR
//         DD DSN=CEE.SCEERUN,DISP=SHR
//         DD DSN=DB2.V13R1M0.SDSNLOAD,DISP=SHR
//         DD DSN=DB2.V13R1M0.SDSNLOD2,DISP=SHR
//         DD DSN=EQAW.SEQAMOD,DISP=SHR
//         DD DSN=TCPIP.SEZATCP,DISP=SHR
//         DD DSN=EQAW.EQAIVP.LOAD,DISP=SHR
//         DD DSN=SYS1.MIGLIB,DISP=SHR
//         DD DSN=SYS1.SIEAMIGE,DISP=SHR
//* NEXT 2 ADDED FOR DEBUG
//*  Begin Ansible GENAPP Block Insert
//         DD DSN=IBMUSER.CB12V51.LOAD,DISP=SHR
//*  End Ansible GENAPP Block Insert
//EQADPFMB DD DISP=SHR,DSN=CICSTS61.CICS.EQADPFMB
//DFHTABLE DD DISP=SHR,DSN=CICSTS61.SYSIN(DFHPLT)
//*  End Ansible of 1st Insert Block  *//
//*        DD DSN=CEE.SCEECICS,DISP=SHR
//*        DD DSN=CEE.SCEERUN2,DISP=SHR
//*        DD DSN=CEE.SCEERUN,DISP=SHR
//*        DD DSN=SYS1.SCSQLOAD,DISP=SHR
//*        DD DSN=SYS1.SCSQANLE,DISP=SHR
//*        DD DSN=SYS1.SCSQCICS,DISP=SHR
//*        DD DSN=SYS1.SCSQAUTH,DISP=SHR
//*        THE AUXILIARY TEMPORARY STORAGE DATASET
//DFHTEMP  DD DISP=SHR,
// DSN=&INDEX1..CNTL.CICS&REGNAM..DFHTEMP
//*        THE INTRAPARTITION DATASET
//DFHINTRA DD DISP=SHR,
// DSN=&INDEX1..CNTL.CICS&REGNAM..DFHINTRA
//*        THE AUXILIARY TRACE DATASETS
//DFHAUXT  DD DISP=SHR,DCB=BUFNO=5,
// DSN=&INDEX1..CICS&REGNAM..DFHAUXT
//DFHBUXT  DD DISP=SHR,DCB=BUFNO=5,
// DSN=&INDEX1..CICS&REGNAM..DFHBUXT
//*        THE CICS LOCAL CATALOG DATASET
//DFHLCD   DD DISP=SHR,
// DSN=&INDEX1..CICS&REGNAM..DFHLCD
//*        THE CICS GLOBAL CATALOG DATASET
//DFHGCD   DD DISP=SHR,
// DSN=&INDEX1..CICS&REGNAM..DFHGCD
//*            AMP=('BUFND=33,BUFNI=32,BUFSP=1114112')
//*        THE CICS LOCAL REQUEST QUEUE DATASET
//DFHLRQ   DD DISP=SHR,
// DSN=&INDEX1..CICS&REGNAM..DFHLRQ
//* EXTRAPARTITION DATASETS
//DFHCXRF  DD SYSOUT=&OUTC
//LOGUSR   DD SYSOUT=&OUTC,DCB=(DSORG=PS,RECFM=V,BLKSIZE=136)
//MSGUSR   DD SYSOUT=&OUTC,DCB=(DSORG=PS,RECFM=V,BLKSIZE=140)
//CEEMSG   DD SYSOUT=&OUTC
//CEEOUT   DD SYSOUT=&OUTC
//*        THE DUMP DATASETS
//DFHDMPA  DD DISP=SHR,
// DSN=&INDEX1..CICS&REGNAM..DFHDMPA
//DFHDMPB  DD DISP=SHR,
// DSN=&INDEX1..CICS&REGNAM..DFHDMPB
//SYSABEND DD SYSOUT=&OUTC
//SYSPRINT DD SYSOUT=&OUTC
//PRINTER  DD SYSOUT=&OUTC,DCB=BLKSIZE=121
//*        THE CICS SYSTEM DEFINITION DATASET
//DFHCSD   DD DISP=SHR,
// DSN=&INDEX1..DFHCSD
//* EXECUTE DUMP UTILITY PROGRAM TO PRINT THE
//* CONTENTS OF THE DUMP DATASET A
//PRTDMPA  EXEC  PGM=DFHDU740,PARM=SINGLE,
// REGION=0M,COND=(1,NE,DTCNTL)
//STEPLIB  DD DSN=&INDEX2..SDFHLOAD,DISP=SHR
//DFHTINDX DD SYSOUT=&OUTC
//SYSPRINT DD SYSOUT=&OUTC
//DFHPRINT DD SYSOUT=&OUTC
//DFHDMPDS DD DISP=SHR,
// DSN=&INDEX1..CICS&REGNAM..DFHDMPA
//SYSIN    DD DUMMY
//*        EXECUTE DUMP UTILITY PROGRAM TO PRINT THE
//*        CONTENTS OF THE DUMP DATASET B
//PRTDMPB  EXEC  PGM=DFHDU740,PARM=SINGLE,
// REGION=0M,COND=(1,NE,DTCNTL)
//STEPLIB  DD DSN=&INDEX2..SDFHLOAD,DISP=SHR
//DFHTINDX DD SYSOUT=&OUTC
//SYSPRINT DD SYSOUT=&OUTC
//DFHPRINT DD SYSOUT=&OUTC
//DFHDMPDS DD DISP=SHR,
// DSN=&INDEX1..CICS&REGNAM..DFHDMPB
//SYSIN    DD DUMMY
//*        EXECUTE TRACE UTILITY PROGRAM TO PRINT THE
//*        CONTENTS OF THE AUXILIARY TRACE DATASET 'A'.
//*        THIS DATASET WILL BE EMPTY UNLESS SIT
//*        PARAMETER AUXTR IS SET TO ON.
//PRTAUXT  EXEC PGM=DFHTU740,REGION=0M,COND=(1,NE,DTCNTL)
//STEPLIB  DD DSN=&INDEX2..SDFHLOAD,DISP=SHR
//DFHAUXT  DD DISP=SHR,
// DSN=&INDEX1..CICS&REGNAM..DFHAUXT
//DFHAXPRT DD SYSOUT=&OUTC
//DFHAXPRM DD DUMMY
//*        EXECUTE TRACE UTILITY PROGRAM TO PRINT THE
//*        CONTENTS OF THE AUXILIARY TRACE DATASET 'B'.
//*        THIS DATASET WILL BE EMPTY UNLESS SIT
//*        PARAMETER AUXTR IS SET TO ON.
//PRTBUXT  EXEC PGM=DFHTU740,REGION=0M,COND=(1,NE,DTCNTL)
//STEPLIB  DD DSN=&INDEX2..SDFHLOAD,DISP=SHR
//DFHAUXT  DD DISP=SHR,
// DSN=&INDEX1..CICS&REGNAM..DFHBUXT
//DFHAXPRT DD SYSOUT=&OUTC
//DFHAXPRM DD DUMMY
//*
//*
