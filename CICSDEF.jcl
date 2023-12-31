//IBMUSERD  JOB 'ACCT#',MSGCLASS=H
//* This job adds your extracted Dev CICS app definitions to
//* your new zOS/CICS instance.
//* Requires that you run the APPDUMP job on your dev system first
//* Steplib and CSD are based on Wazi aaS zOS image of june 2022
//* No changes are needed to this JCL
//* due to CRLF issue pad each line with blanks pass 80
//S1 SET LOAD=CICSTS.V6R1M0.CICS.SDFHLOAD
//S2 SET CSD=CICSTS61.DFHCSD
//*
//TRN    EXEC PGM=DFHCSDUP,REGION=0M,
//       PARM='CSD(READWRITE),PAGESIZE(60),NOCOMPAT'
//STEPLIB  DD DISP=SHR,DSN=&LOAD
//DFHCSD   DD DISP=SHR,DSN=&CSD
//SYSPRINT DD SYSOUT=*
//SYSIN    DD DISP=SHR,DSN=IBMUSER.JCL(CICSDEF)
