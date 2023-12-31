/* REXX */
/* NJL-v5 PATCH bug with ziploc fodler names has a comp id - hardcoding 
       demo loc  
*/

/*%STUB CALLCMD*/
/*********************************************************************/
/*                                                                   */
/*                                                                   */
/*                                                                   */
/* Copyright:    Licensed Materials - Property of IBM and/or HCL     */
/*                                                                   */
/*            "Restricted Materials of IBM and HCL"                  */
/*                                                                   */
/*               5725-M54                                            */
/*                                                                   */
/*               Copyright IBM Corp. 2018                            */
/*               Copyright HCL Tech. 2018-19                         */
/*               All rights reserved                                 */
/*                                                                   */
/*               US Government Users Restricted Rights -             */
/*               Use, duplication or disclosure restricted by        */
/*               GSA ADP Schedule Contract with IBM Corp.            */
/*                                                                   */
/*********************************************************************/
/*                                                                   */
/*                                                                   */
/* NAME := BUZDEPZP                                                  */
/*                                                                   */
/* DESCRIPTIVE NAME := Deployment module                             */
/*                                                                   */
/* FUNCTION := Using the deploy manifest file deploy the contents of */
/*             the specified zip file                                */
/*                                                                   */
/* CALLED BY : None                                                  */
/*                                                                   */
/* PARAMETERS : manifest - File containing the data sets and members */
/*                         to deploy                                 */
/*              ziploc   - Location where to find zip to deploy      */
/*              pgkzip   - Name of the zip file to deploy            */
/*              restore  - Name of restore mapping file. Contains    */
/*                         old to new file names                     */
/*              binloc   - Location where the zip is already         */
/*                         unpacked, optional (new in 6.0.3)         */
/*                                                                   */
/* OUTPUT := None                                                    */
/*                                                                   */
/* Change History                                                    */
/*                                                                   */
/* Who   When     What                                               */
/* ----- -------- -------------------------------------------------- */
/* LD    15/09/10 Initial version                                    */
/* TT    09/03/11 Message separation                                 */
/* LD    13/04/11 Use temp data set for receive                      */
/* TI    10/22/12 Add REXX and runtime version check                 */
/* LD    29/04/13 Change temporary data set name to be unique        */
/* TONY  01/06/14 Reuse code for UCD                                 */
/* LD    23/06/14 Change LMCOPY to IEBCOPY - WI 320228               */
/* LD    23/07/14 Fix COPYGRP statment to refplace - WI 325028       */
/* LD    08/09/14 Handle deletions                         WI-328415 */
/* LD    16/09/14 Handle sequential files                  WI-329452 */
/* LD    28/05/15 Write recieve log to a throwaway data set          */
/* LD/TON26/05/16 Use provided prefix if set               WI-387942 */
/* JS    13/06/16 Support HFS files in deployment          WI-391809 */
/* TONY  29/06/17 Deploy PDSE members based on packageManifest       */
/* TONY  01/09/17 Fix variable initialization defect for IEBCOPY     */
/* LD/TO 14/11/17 Support packaging IMS TFORMAT members    WI-443217 */
/* SEN   10/07/18 Fix for big temp file creation in allocate PH00387 */
/*                                                                   */
/*********************************************************************/

   Call syscalls('ON')

   parse arg Module '"'manifest'"' '"'ziploc'"' '"'pkgzip'"' '"'restore'"',
                '"'buildDefVersion'"' '"'runtimeVersion'"' '"'uninstallFile'"',
                '"'traceOption'"' '"'tempDsnPrefix'"' '"'binloc'"',
                '"'sysoutValue'"' '"'tempUnitValue'"' '"'tempVolSerValue'"'.


SAY "** NJL-PATCH001 - ZIPLOC OLD " ziploc
ziploc =  '/u/ibmuser/ibm-ucd/agent/var/work/poc-component'
SAY "** NJL-PATCH001 - ZIPLOC NEW " ziploc



   Parse var traceOption TraceOn '(' TraceMod ')'
   TraceCmd = ''
   If Substr(TraceOn,1,5) = 'TRACE' Then
   Do
     modname = 'BUZDEPZP'
     If TraceMod = 'ALL' |,
        TraceMod = modname Then
     Do
       Say "*** Tracing activated for "modname "on "Date('N') ||,
           " at "Time()" ***"
       Select
         When (TraceOn = 'TRACE?I') Then TraceCmd = 'Trace ?i'
         When (TraceOn = 'TRACEI')  Then TraceCmd = 'Trace i'
         When (TraceOn = 'TRACEA')  Then TraceCmd = 'Trace a'
         When (TraceOn = 'TRACER')  Then TraceCmd = 'Trace r'
         When (TraceOn = 'TRACEC')  Then TraceCmd = 'Trace c'
         When (TraceOn = 'TRACEE')  Then TraceCmd = 'Trace e'
         When (TraceOn = 'TRACEF')  Then TraceCmd = 'Trace f'
         When (TraceOn = 'TRACEL')  Then TraceCmd = 'Trace l'
         When (TraceOn = 'TRACEN')  Then TraceCmd = 'Trace n'
         When (TraceOn = 'TRACE')   Then TraceCmd = 'Trace r'
         Otherwise NOP
       End
     End
   End
   Interpret TraceCmd

   /* Get Sysout class and temp unit and volser */
   sysoutClass = ''
   tempUnit    = 'SYSALLDA'
   tempVolser  = ''
   If sysoutValue /= "" Then
   Do
     sysoutClass = 'SYSOUT('sysoutValue')'
   End
   If tempUnitValue /= "" Then
   Do
     tempUnit  = tempUnitValue
   End
   If tempVolSerValue /= "" Then
   Do
     tempVolser  = 'VOLUME('tempVolSerValue')'
   End

   /* Get TSO prefix or userid for temporary files */

   USERID = USERID()
   elapsed = Time('E')

   If tempDsnPrefix /= '' Then
     prefix = tempDsnPrefix
   Else
   Do
     x = outtrap(profile.)
     Address TSO "PROFILE"
     x = outtrap('OFF')

     If profile.0 <> 0 Then
     Do
       prefix = ''
       Do y = 1 to profile.0
         Parse var profile.y . 'PREFIX(' prefix ')' .
         If prefix <> '' Then leave
       End
     End
     Select
       When (prefix = '') Then
         prefix = USERID
       When (prefix = USERID) Then
         prefix = USERID
       Otherwise
         prefix = prefix'.'USERID
     End
   End

   /* BUZD156 BUZD157*/
   /* Say "Toolkit version number" */
   Address ISPEXEC 'GETMSG MSG(BUZD156) LONGMSG(BUZLNGER)'
   TOOLKIT_VERSION = BUZLNGER
   Address ISPEXEC 'GETMSG MSG(BUZD157) LONGMSG(BUZLNGER)'
   BUILD_STAMP = BUZLNGER
   Say 'Toolkit version:'TOOLKIT_VERSION' ('BUILD_STAMP')'

   /* BUZD101 */
   /* Say "Manifest file            : "manifest */
   BUZMARG1 = manifest
   Address ISPEXEC 'GETMSG MSG(BUZD101) LONGMSG(BUZLNGER)'
   Say BUZLNGER

   /* BUZD102 */
   /* Say "Location of the zip file : "ziploc */
   BUZMARG1 = ziploc
   Address ISPEXEC 'GETMSG MSG(BUZD102) LONGMSG(BUZLNGER)'
   Say BUZLNGER

   /* BUZD103 */
   /* Say "Name of backup zip file  : "pkgzip */
   BUZMARG1 = pkgzip
   Address ISPEXEC 'GETMSG MSG(BUZD103) LONGMSG(BUZLNGER)'
   Say BUZLNGER

   /* BUZD159 */
   /* Say "Unpacked location        : "binloc */
   BUZMARG1 = binloc
   Address ISPEXEC 'GETMSG MSG(BUZD159) LONGMSG(BUZLNGER)'
   Say BUZLNGER

   /* BUZD104 */
   /* Say "Restore Mapping File     : "restore */
   BUZMARG1 = restore
   Address ISPEXEC 'GETMSG MSG(BUZD104) LONGMSG(BUZLNGER)'
   Say BUZLNGER

   If uninstallFile /= '' Then Do
     Call uninstall
   End
   Else
   Do
     Call initialize                 /* read input files and set up */

     /* check whether REXX version is equal or greater than runtime version */
     /* Get the toolkit version */
     Address ISPEXEC 'GETMSG MSG(BUZD156) LONGMSG(BUZMARG1)'
     If (BUZMARG1 >= runtimeVersion) Then
     Do
       /* BUZD133 */
       /* Say "Running deploy for version 3.0.1" */
       Call setdsnsV301
       Call deploy                     /* do the receives             */
     End
     Else
     Do
       /* BUZD151 */
       /* Say "REXX version is lower than runtime version " */
       BUZMARG2 = runtimeVersion
       Address ISPEXEC 'GETMSG MSG(BUZD151) LONGMSG(BUZLNGER)'
       Say BUZLNGER
       Call Exitproc(8)
     End
   End

   elapsed = Time('E')
   BUZMARG1 = elapsed
   Address ISPEXEC 'GETMSG MSG(BUZP110) LONGMSG(BUZLNGER)'
   Say BUZLNGER

Exit

Initialize :

   /* Get z/OS release */
   Address ISPEXEC 'VGET (ZOS390RL) SHARED'
   Parse var ZOS390RL 'z/OS' ZOSREL'.'ZOSVER'.'ZOSMOD
   ZOSREL = Strip(ZOSREL)
   ZOSVER = Strip(ZOSVER)
   ZOSMOD = Strip(ZOSMOD)

   manlist.0 = 0
   Address syscall "readfile (manifest) manlist."
   If retval < 0 Then
   Do
      /* BUZD109 */
      /* Say "Problem reading manifest file : "manifest". " ||, */
      /*     "Errno : "errno" Reason : "right(errnojr,8,0) */
      BUZMARG1 = manifest
      BUZMARG2 = errno
      BUZMARG3 = right(errnojr,8,0)
      Address ISPEXEC 'GETMSG MSG(BUZD109) LONGMSG(BUZLNGER)'
      Say BUZLNGER
      Call Exitproc(8)
   End

   maplist.0 = 0
   If restore <> '' Then
   Do
      Address syscall "readfile (restore) maplist."
      If retval < 0 Then
      Do
         /* BUZD111 */
         /* Say "Problem reading mapping file : "restore". " ||, */
         /*     "Errno : "errno" Reason : "right(errnojr,8,0) */
         BUZMARG1 = restore
         BUZMARG2 = errno
         BUZMARG3 = right(errnojr,8,0)
         Address ISPEXEC 'GETMSG MSG(BUZD111) LONGMSG(BUZLNGER)'
         Say BUZLNGER
         Call Exitproc(8)
      End
   End
   Else
   Do
      /* BUZD112 */
      /* Say "No restore mapping file found, manifest loacation will be used"*/
      Address ISPEXEC 'GETMSG MSG(BUZD112) LONGMSG(BUZLNGER)'
      Say BUZLNGER
   End

Return

setdsnsV301 :

   /* Create a mapping list package data set to deploy      */
   /* data set.                                             */

   k = 0
   RecvMap.0 = k
   Do i = 1 to manlist.0
     Select
       When (Pos('<created>',manlist.i) > 0) Then
         MemAct = 'CREATED'

       When (Pos('<updated>',manlist.i) > 0) Then
         MemAct = 'UPDATED'

       When (Pos('<deleted>',manlist.i) > 0) Then
         MemAct = 'DelMem'

       When (Pos('</deleted>',manlist.i) > 0) Then
         MemAct = ''

       When (Pos('<container',manlist.i) > 0) Then
       Do
         Parse var manlist.i . '<container'BegLine'name="' DataSet '"'RestLine

          /* Ignore directory (i.e. HFS) containers. They are handled by Ant. */
         If Pos('type="directory"',manlist.i) > 0 Then
           Do
           /* Say "Skipping directory container "DataSet */
           i = i + 1
           Do while (Pos('<resource',manlist.i) > 0)
             i = i + 1
           End
           i = i - 1
           iterate
         End


         /* Need to see if this is a sequential file */
         If Pos('type="sequential"',RestLine) > 0 Then
           Sequential = 1
         Else
           Sequential = 0

         /* Deploy can use packageManifest or a rollback manifest */
         /* They have different formats. Rollback uses changeType */
         /* as it was created from the deltaDeployed.xml.         */
         /* Need to handle deletion of data sets as well          */
         Action = ''
         Parse var RestLine . 'changeType="' Action '"' .
         if Action = '' Then
         Do
            Parse var BegLine . 'changeType="' Action '"' .
         End

         /* If we are in a delete block in packagemanifest and    */
         /* this is a sequential then we need to delete it.       */
         /* Members are already handled below.                    */
         If MemAct = 'DelMem' & sequential Then
           Action = 'Delete'

         /* Loop through restore mapping file to see if */
         /* there is an entry for the data set. If so   */
         /* replace it in the list.                     */
         DeplDSN = Strip(DataSet)
         Do rest = 1 to maplist.0
            If Pos('<?xml',maplist.rest) > 0 Then
               iterate
            If Pos('<maps>',maplist.rest) > 0  |,
               Pos('</maps>',maplist.rest) > 0 Then
               iterate
            If Pos('<map type="PDS">',maplist.rest) > 0  |,
               Pos('<map type="sequential">',maplist.rest) > 0  |,
               Pos('</map>',maplist.rest) > 0 Then
               iterate
            If Pos('<sourceContainer',maplist.rest) > 0 Then
            Do
               Parse var maplist.rest . '<sourceContainer name="' OrigDSN,
                                        '" />' .
               rest = rest + 1

            End
            If Pos('<targetContainer',maplist.rest) > 0 Then
               Parse var maplist.rest . '<targetContainer name="' ToDSN,
                                        '" />' .
            Else
            Do
               /* BUZD114 */
               /* Say 'Deploy to data set not specified for 'OrigDSN */
               BUZMARG1 = OrigDSN
               Address ISPEXEC 'GETMSG MSG(BUZD114) LONGMSG(BUZLNGER)'
               Say BUZLNGER
               Call Exitproc(8)
            End
            OrigDSN = Strip(OrigDSN)
            ToDSN   = Strip(ToDSN)
            If DataSet = OrigDSN Then
            Do
               DeplDSN = ToDSN
               manlist.i = 'DataSet='ToDSN
               Leave
            End
         End

         i = i + 1
         j = 0
         FirstMem = 1
         ChangeAction = 'true'
         memberlist.0 = 0
         memberindex = 0
        Do while Pos('<resource',manlist.i) > 0 |,
                 Pos('<property',manlist.i) > 0 |,
                 Pos('</resource',manlist.i) > 0
           if  Pos('<property',manlist.i) > 0 |,
               Pos('</resource',manlist.i) > 0 then
           do
             i = i + 1
             iterate
           end
           Parse var manlist.i . '<resource'.'name="' member '"' .
          /* Need to change the XML format chars to real chars */
           member = chkmem3(member)
            If MemAct = 'DelMem' Then
            Do
               /* If there is a member delete there may be more */
               /* than one. Do the LMINIT once, then process    */
               /* all the member deletes. Then the LMFREE after */
               If FirstMem = 1 Then
               Do
                  FirstMem = 0
                  Address ISPEXEC "LMINIT DATAID(DID) "         ||,
                                     " DATASET('"Strip(DeplDSN)"')" ||,
                                     " ENQ(SHRW)"
                  If (rc = 8) then
                  Do
                    BUZMARG1 = DeplDSN
                    BUZMARG2 = member
                    Address ISPEXEC 'GETMSG MSG(BUZD155) LONGMSG(BUZLNGER)'
                    Say BUZLNGER
                    FirstMem = 1
                    i = i + 1
                    Iterate
                  End
                  Else
                    If (rc > 0) then
                    Do
                      /* BUZD126 */
                      /* Call ISPFerr ('LMINIT on 'DeplDSN' failed rc='rc)*/
                       BUZMARG1 = DeplDSN
                       BUZMARG2 = rc
                       Address ISPEXEC 'GETMSG MSG(BUZD126) LONGMSG(BUZLNGER)'
                       Call ISPFerr (BUZLNGER' rc='BUZMARG2)
                    End

                  Address ISPEXEC "LMOPEN DATAID(&DID) OPTION(OUTPUT)"
                  If (rc > 0) then
                  Do
                     /* BUZD127 */
                     /* Call ISPFerr ('LMOPEN on 'DeplDSN' failed rc='rc) */
                     BUZMARG1 = DeplDSN
                     BUZMARG2 = rc
                     Address ISPEXEC 'GETMSG MSG(BUZD127) LONGMSG(BUZLNGER)'
                     Call ISPFerr (BUZLNGER' rc='BUZMARG2)
                  End
               End

               /* BUZD134 */
               /* Say "Deleting member "member" from "DeplDSN */
               BUZMARG1 = member
               BUZMARG2 = DeplDSN
               Address ISPEXEC 'GETMSG MSG(BUZD134) LONGMSG(BUZLNGER)'
               Say BUZLNGER

               Address ISPEXEC "LMMDEL DATAID(&DID) MEMBER("member")"
               Select
                  When (rc = 0) Then
                     Nop
                  When (rc = 8) Then
                  Do
                     /* BUZD135 */
                     /* Say "Member delete of member "member" failed." ||, */
                     /*    "Member did not exist in deploy zip" */
                     BUZMARG1 = member
                     Address ISPEXEC 'GETMSG MSG(BUZD135) LONGMSG(BUZLNGER)'
                     Say BUZLNGER
                  End
                  Otherwise
                  Do
                     /* BUZD136 */
                     /* Call ISPFerr ('Member delete of member ' ||, */
                     /*               member' failed rc='rc) */
                     BUZMARG1 = member
                     BUZMARG2 = rc
                     Address ISPEXEC 'GETMSG MSG(BUZD136) LONGMSG(BUZLNGER)'
                     Call ISPFerr (BUZLNGER' rc='BUZMARG2)
                  End
               End
            End
            Else
            do
               ChangeAction = 'false'
               memberindex = memberindex + 1
               /* change characters to wildcards for IEBCOPY           */
               member = chkmem2(member)
               memberlist.memberindex = member
               memberlist.0 = memberindex
            end
            i = i + 1
         End
         If ChangeAction = 'true' & Sequential = 0 Then
         Do
            If Action \= 'Delete' & Action \= 'DELETE' Then
            Do
               Action = 'Empty'
            End
         End

         If FirstMem = 0 Then
         Do
            Address ISPEXEC "LMCLOSE DATAID(&DID)"
            If (rc <> 0) then
            Do
               /* BUZD131 */
               /* Call ISPFerr ('LMCLOSE failed rc='rc) */
               BUZMARG1 = rc
               Address ISPEXEC 'GETMSG MSG(BUZD131) LONGMSG(BUZLNGER)'
               Call ISPFerr (BUZLNGER' rc='BUZMARG1)
            End

            Address ISPEXEC "LMFREE DATAID(&DID)"
            If (rc <> 0) then
            Do
               /* BUZD132 */
               /* Call ISPFerr ('LMFREE failed rc='rc) */
               BUZMARG1 = rc
               Address ISPEXEC 'GETMSG MSG(BUZD132) LONGMSG(BUZLNGER)'
               Call ISPFerr (BUZLNGER' rc='BUZMARG1)
            End
         End
         Call Proc_Action
         i = i - 1
       End
       Otherwise
         Nop
     End
   End
   RecvMap.0 = k

Return

setdsns :

   /* Create a mapping list package data set to deploy      */
   /* data set.                                             */

   k = 0
   RecvMap.0 = k
   Do i = 1 to manlist.0
      If Pos('<sourcePDS>',manlist.i) > 0 Then
      Do
         Parse var manlist.i . '<sourcePDS>' DataSet Action '</sourcePDS>' .
         /* Loop through restore mapping file to see if */
         /* there is an entry for the data set. If so   */
         /* replace it in the list.                     */
         DeplDSN = Strip(DataSet)
         Do rest = 1 to maplist.0
            If Pos('<file>',maplist.rest) > 0  |,
               Pos('</file>',maplist.rest) > 0 Then
               iterate
            If Pos('<sourcePDS>',maplist.rest) > 0 Then
            Do
               Parse var maplist.rest . '<sourcePDS>' OrigDSN Action,
                                        '</sourcePDS>' .
               rest = rest + 1

            End
            If Pos('<targetPDS>',maplist.rest) > 0 Then
               Parse var maplist.rest . '<targetPDS>' ToDSN '</targetPDS>' .
            Else
            Do
               /* BUZD114 */
               /* Say 'Deploy to data set not specified for 'OrigDSN */
               BUZMARG1 = OrigDSN
               Address ISPEXEC 'GETMSG MSG(BUZD114) LONGMSG(BUZLNGER)'
               Say BUZLNGER
               Call Exitproc(8)
            End
            OrigDSN = Strip(OrigDSN)
            ToDSN   = Strip(ToDSN)
            If DataSet = OrigDSN Then
            Do
               DeplDSN = ToDSN
               manlist.i = 'DataSet='ToDSN
               Leave
            End
         End
         i = i + 1
         j = 0
         FirstMem = 1
         Do while (Pos('<sourceMember>',manlist.i) > 0)
            Parse var manlist.i . '<sourceMember>' member MemAct,
                                  '</sourceMember>' .
            If MemAct = 'DelMem' Then
            Do
               /* If there is a member delete there may be more */
               /* than one. Do the LMINIT once, then process    */
               /* all the member deletes. Then the LMFREE after */
               If FirstMem = 1 Then
               Do
                  FirstMem = 0
                  Address ISPEXEC "LMINIT DATAID(DID) "         ||,
                                     " DATASET('"Strip(DeplDSN)"')" ||,
                                     " ENQ(SHRW)"
                  If (rc > 0) then
                  Do
                     /* BUZD126 */
                     /* Call ISPFerr ('LMINIT on 'DeplDSN' failed rc='rc) */
                     BUZMARG1 = DeplDSN
                     BUZMARG2 = rc
                     Address ISPEXEC 'GETMSG MSG(BUZD126) LONGMSG(BUZLNGER)'
                     Call ISPFerr (BUZLNGER' rc='BUZMARG2)
                  End

                  Address ISPEXEC "LMOPEN DATAID(&DID) OPTION(OUTPUT)"
                  If (rc > 0) then
                  Do
                     /* BUZD127 */
                     /* Call ISPFerr ('LMOPEN on 'DeplDSN' failed rc='rc) */
                     BUZMARG1 = DeplDSN
                     BUZMARG2 = rc
                     Address ISPEXEC 'GETMSG MSG(BUZD127) LONGMSG(BUZLNGER)'
                     Call ISPFerr (BUZLNGER' rc='BUZMARG2)
                  End
               End

               /* BUZD134 */
               /* Say "Deleting member "member" from "DeplDSN */
               BUZMARG1 = DeplDSN
               Address ISPEXEC 'GETMSG MSG(BUZD134) LONGMSG(BUZLNGER)'
               Say BUZLNGER

               Address ISPEXEC "LMMDEL DATAID(&DID) MEMBER("member")"
               Select
                  When (rc = 0) Then
                     Nop
                  When (rc = 8) Then
                  Do
                     /* BUZD135 */
                     /* Say "Member delete of member "member" failed." ||, */
                     /*    "Member did not exist in deploy zip" */
                     BUZMARG1 = member
                     Address ISPEXEC 'GETMSG MSG(BUZD135) LONGMSG(BUZLNGER)'
                     Say BUZLNGER
                  End
                  Otherwise
                  Do
                     /* BUZD136 */
                     /* Call ISPFerr ('Member delete of member ' ||, */
                     /*               member' failed rc='rc) */
                     BUZMARG1 = member
                     BUZMARG2 = rc
                     Address ISPEXEC 'GETMSG MSG(BUZD136) LONGMSG(BUZLNGER)'
                     Call ISPFerr (BUZLNGER' rc='BUZMARG2)
                  End
               End
            End
            i = i + 1
         End
         If FirstMem = 0 Then
         Do
            Address ISPEXEC "LMCLOSE DATAID(&DID)"
            If (rc <> 0) then
            Do
               /* BUZD131 */
               /* Call ISPFerr ('LMCLOSE failed rc='rc) */
               BUZMARG1 = rc
               Address ISPEXEC 'GETMSG MSG(BUZD131) LONGMSG(BUZLNGER)'
               Call ISPFerr (BUZLNGER' rc='BUZMARG1)
            End

            Address ISPEXEC "LMFREE DATAID(&DID)"
            If (rc <> 0) then
            Do
               /* BUZD132 */
               /* Call ISPFerr ('LMFREE failed rc='rc) */
               BUZMARG1 = rc
               Address ISPEXEC 'GETMSG MSG(BUZD132) LONGMSG(BUZLNGER)'
               Call ISPFerr (BUZLNGER' rc='BUZMARG1)
            End
         End
         Call Proc_Action
         i = i - 1
      End
   End
   RecvMap.0 = k

Return

Deploy :

   /* There should be a zip file to deploy based on the contents */
   /* of the manifest.                                           */
   If RecvMap.0 > 0 Then
   Do
      /* If binloc is set, skip the unpacking */
      if binloc = '' Then
      Do
         /* Make sure zip file exists */
         fname = ziploc"/"pkgzip

         Address syscall "stat (fname) stat."
         If retval < 0 Then
         Do
            /* BUZD137 */
            /* Say "Problem accessing : "fname". Errno : "errno */
            BUZMARG1 = fname
            BUZMARG2 = errno
            Address ISPEXEC 'GETMSG MSG(BUZD137) LONGMSG(BUZLNGER)'
            Say BUZLNGER
            Call Exitproc(8)
         End

         /* First need to unzip the zip file                          */
         Call UnZip_it pkgzip

         binloc = ziploc
      End

      LongTime = TIME('L')
      Parse var longTime hh':'mm':'ss'.'uuuuuu
      DSNSuf  = 'T'||hh||mm||ss'.M'uuuuuu
      TempDSN = prefix'.RTCRECV.'DSNSuf
      x = msg('off')
      Address TSO "DELETE '"TempDSN"'"
      x = msg('on')

      /* One by one transfer xmit files from HFS to temp data set  */
      /* Receive into the target dataset based on the new manifest */
      Do i = 1 to RecvMap.0
         Parse var RecvMap.i 'RecvDSN='RecvDSN' DeployTo='DeplDSN ' Type='Type
         If Type = 'sequential' Then
           sequential = 1
         Else
           sequential = 0

         /* Now copy sequential from HFS to sequential data set  */
         x = msg('off')
         Address TSO "FREE F(HFSFILE)"
         Address TSO "FREE F(SEQFILE)"
         Address TSO "FREE F(SYSPRINT)"
         x = msg('on')

         /* Need to work out how much space to allocate  */
         /* the .bin file in the HFS will have a size in */
         /* bytes. Convert that to tracks based on the   */
         /* calculation that there are 56664 bytes/track */
         stdout.0 = 0
         stderr.0 = 0

         shellcmd="ls -REgoa '"binloc"/"RecvDSN".bin'"

         sh_rc = bpxwunix(shellcmd,,stdout.,stderr.)
         If stderr.0 > 0 Then
         Do
            Say '---STDERR---'
            Do e = 1 to stderr.0
               Say stderr.e
            End
         End
         If stdout.0 > 0 Then
         Do
           parse var stdout.1 stuff 21 size .
           If size <= 56664 Then
             trk = 1
           Else
             trk = Format(size/56664,,0)
         End

         Address TSO "ALLOC F(SYSPRINT) DUMMY"
         Address TSO "ALLOC F(SEQFILE) NEW" ||,
                 " TRACKS UNIT("tempUnit") "tempVolser" DSORG(PS)" ||,
                 " BLKSIZE(3120) LRECL(80) RECFM(F B)" ||,
                 " SPACE("trk" "trk") DSNTYPE(LARGE)"
         Address TSO "ALLOC F(HFSFILE) PATH('"binloc"/"RecvDSN".bin')"
         Address TSO "OCOPY INDD(HFSFILE) OUTDD(SEQFILE) BINARY"

         Address TSO "FREE F(HFSFILE)"
         /* Get rid of files as we process them */
         shellcmd = "rm '"binloc"/"RecvDSN".bin'"
         sh_rc = bpxwunix(shellcmd,,stdout.,stderr.)
         If stderr.0 > 0 Then
         Do
            Say '---STDERR---'
            Do e = 1 to stderr.0
               Say stderr.e
            End
         End
         If stdout.0 > 0 Then
         Do
            Say '---STDOUT---'
            Do o = 1 to stdout.0
               Say stdout.o
            End
         End

         /* Now receive the file and replace what was there     */

         x = PROMPT("ON")

         /* BUZD138 */
         /* Say 'Deploying members to 'DeplDSN */
         BUZMARG1 = DeplDSN
         If sequential Then
           Address ISPEXEC 'GETMSG MSG(BUZD140) LONGMSG(BUZLNGER)'
         Else
           Address ISPEXEC 'GETMSG MSG(BUZD138) LONGMSG(BUZLNGER)'
         Say BUZLNGER

         /* Allocate a temporary throw away log so we don't */
         /* fill up LOG.MISC                                */

         Address TSO "ALLOC F(LOGFILE) NEW" ||,
              " CYLINDERS UNIT("tempUnit") "tempVolser" DSORG(PS)" ||,
              " BLKSIZE(3120) LRECL(255) RECFM(V B)" ||,
              " SPACE(1 1)"
       Address TSO "ALLOC F(SYSUT4) NEW" ||,
                 " CYLINDERS UNIT("tempUnit") "tempVolser" SPACE(5 10)"
       Address ISPEXEC "QBASELIB LOGFILE ID(LOGFILE)"

         XX=OUTTRAP('STEM.')
         If sequential Then
           Queue " DATASET('"DeplDSN"')" sysoutClass
         Else
           Queue " DATASET('"TempDSN"')" sysoutClass
         Address TSO "RECEIVE INFILE(SEQFILE) NONAMES LOGDS("LOGFILE")"
         if rc <> 0 Then
         Do
            Do xmit = 1 to stem.0
               Say stem.xmit
            End
            Address TSO "FREE F(LOGFILE)"
            Address TSO "FREE F(SEQFILE)"
            Address TSO "FREE F(SYSPRINT)"
            Address TSO "FREE F(SYSUT4)"
            Call ExitProc(8)
         End
         XX=OUTTRAP('OFF')
         Address TSO "FREE F(SYSPRINT)"
         Address TSO "FREE F(LOGFILE)"

         x = msg('off')
         Address TSO "FREE F(SYSIN)"
         Address TSO "FREE F(SYSPRINT)"
         Address TSO "FREE F(SYSUT4)"
         Address TSO "FREE F(OUTDD)"
         Address TSO "FREE F(INDD)"
         x = msg('on')

         /* Now copy from tempdsn to deploy to data set */

         If sequential Then
           Nop
         Else
         Do

           Address ISPEXEC "DSINFO DATASET('"DeplDSN"')"
           If (rc > 0) then
           Do
             If (rc = 8) Then  /* Data set does not exist */
             Do
               /* BUZP107 */
               BUZMARG1 = ZERRLM
               BUZMARG2 = RecvDSN
               Address ISPEXEC 'GETMSG MSG(BUZP107) LONGMSG(BUZLNGER)'
               Say BUZLNGER
               Address ISPEXEC "DSINFO DATASET('"TempDSN"')"
               If (rc > 0) then
               Do
                 /* BUZP108 */
                 BUZMARG1 = TempDSN
                 BUZMARG2 = rc
                 Address ISPEXEC 'GETMSG MSG(BUZP108) LONGMSG(BUZLNGER)'
                 Call ISPFerr (BUZLNGER ||' rc='||BUZMARG2)
               End

               blksize = Strip(zdsblk)
               Address TSO "ALLOC DA('"Strip(DeplDSN)"') " ||,
                             "LIKE('"Strip(TempDSN)"') BLKSIZE("blksize")"
               If (rc > 0) then
               Do
                  /* BUZP100 */
                  BUZMARG1 = DeplDSN
                  BUZMARG2 = rc
                  Address ISPEXEC 'GETMSG MSG(BUZP100) LONGMSG(BUZLNGER)'
                  Call ISPFerr (BUZLNGER ||' rc='||BUZMARG2)
               End
             End
             Else
             Do
               /* BUZP108 */
               BUZMARG1 = DeplDSN
               BUZMARG2 = rc
               Address ISPEXEC 'GETMSG MSG(BUZP108) LONGMSG(BUZLNGER)'
               Call ISPFerr (BUZLNGER || ' rc='||BUZMARG2)
             End
           End

            Address ISPEXEC "DSINFO DATASET('"DeplDSN"')"
           /* If pre-zOS  2.1 and not a PDSE then use LMCOPY */
           If (zOSREL < '02' & ZDSDSNT /= 'LIBRARY') |,
              TRACEMOD = 'LMCOPY' Then
           Do
             Address ISPEXEC "LMINIT DATAID(DID) " ||,
                                   " DATASET('"TempDSN"')" ||,
                                   " ENQ(SHR)"
             If (rc > 0) then
             Do
                BUZMARG1 = DataSet
                BUZMARG2 = rc
                Address ISPEXEC 'GETMSG MSG(BUZP106) LONGMSG(BUZLNGER)'
                Call ISPFerr (BUZLNGER || ' rc='||BUZMARG2)
             End

             Address ISPEXEC "LMINIT DATAID(DOD) " ||,
                                   " DATASET('"Strip(DeplDSN)"')" ||,
                                   " ENQ(SHRW)"
             If (rc > 0) then
             Do
               /* BUZP106 */
               BUZMARG1 = 'TEMPPDS'
               BUZMARG2 = rc
               Address ISPEXEC 'GETMSG MSG(BUZP106) LONGMSG(BUZLNGER)'
               Call ISPFerr (BUZLNGER || ' rc='||BUZMARG2)
             End
             Address ISPEXEC "CONTROL ERRORS RETURN"
             Address ISPEXEC "LMCOPY FROMID(&DID) "   ||,
                                    "FROMMEM(*) "     ||,
                                    "TODATAID(&DOD) " ||,
                                    "REPLACE"
             If (rc <> 0) then
             Do
               BUZMARG1 = '*'
               BUZMARG2 = rc
               Address ISPEXEC 'GETMSG MSG(BUZP109) LONGMSG(BUZLNGER)'
               Call ISPFerr (BUZLNGER || ' rc='||BUZMARG2)
             End
             Copy_rc = rc
             Address ISPEXEC "CONTROL ERRORS CANCEL"
             Address ISPEXEC "LMFREE DATAID(&DID)"
             If (rc <> 0) then
             Do
               /* BUZP111 */
               /* Call ISPFerr ('LMFREE failed with rc='||rc) */
               BUZMARG1 = rc
               Address ISPEXEC 'GETMSG MSG(BUZP111) LONGMSG(BUZLNGER)'
               Call ISPFerr (BUZLNGER || ' rc='||BUZMARG1)
             End
             Address ISPEXEC "LMFREE DATAID(&DOD)"
             If (rc <> 0) then
             Do
               /* BUZP111 */
               /* Call ISPFerr ('LMFREE failed with rc='||rc) */
               BUZMARG1 = rc
               Address ISPEXEC 'GETMSG MSG(BUZP111) LONGMSG(BUZLNGER)'
               Call ISPFerr (BUZLNGER || ' rc='||BUZMARG1)
             End

           End
           Else
           Do
             x = msg('off')
             Address TSO "FREE F(TEMPPDS)"
             x = msg('on')

             Address TSO "ALLOC F(SYSPRINT) NEW REUSE" sysoutClass

             Address TSO "ALLOC F(INDD)  DA('"TempDSN"') SHR REUSE"
             If (rc > 0) then
             Do
                BUZMARG1 = TempDSN
                BUZMARG2 = rc
                Address ISPEXEC 'GETMSG MSG(BUZP100) LONGMSG(BUZLNGER)'
                Call ISPFerr (BUZLNGER || ' rc='||BUZMARG2)
             End
             Address TSO "ALLOC F(OUTDD) DA('"DeplDSN"') SHR REUSE"
             If (rc > 0) then
             Do
                BUZMARG1 = DeplDSN
                BUZMARG2 = rc
                Address ISPEXEC 'GETMSG MSG(BUZP100) LONGMSG(BUZLNGER)'
                Call ISPFerr (BUZLNGER || ' rc='||BUZMARG2)
             End

             Address TSO "ALLOC F(SYSIN) NEW REUSE"
             Address TSO "ALLOC F(SYSUT4) NEW" ||,
                     " CYLINDERS UNIT("tempUnit") SPACE(5 10) " ||,
                     tempVolser

             DROP SYSLINE.
             /* From zOS 2.1 onwards we can use the COPYGROUP for alias */
             /* or if data set is a PDSE we can use COPYGRP for alias */
             If zOSREL >= '02' Then
               SYSLINE.1 = " COPYGROUP OUTDD=OUTDD,INDD=((INDD,R))"
             Else
               SYSLINE.1 = " COPYGRP OUTDD=OUTDD,INDD=((INDD,R))"

             /* support deploying part of a package */
             Do memberindex = 1 to RecvMap.i.MemList.0
                sysIndex = memberindex + 1
                SYSLINE.sysIndex = "         SELECT MEMBER="||,
                             RecvMap.i.MemList.memberindex
             end
             SYSLINE.0 = RecvMap.i.MemList.0 + 1
             say 'IEBCOPY control statement'
             do x = 1 to SYSLINE.0
                say SYSLINE.x
             end
             Address TSO "EXECIO * DISKW SYSIN (STEM SYSLINE. FINIS)"

             Address ISPEXEC "ISPEXEC SELECT PGM(IEBCOPY)"
             Copy_rc = rc
           End

           If Copy_rc /= 0 Then
           Do
             "EXECIO * DISKR SYSPRINT (FINIS STEM sysprint."
             Do xmit = 1 to sysprint.0
               Say Strip(sysprint.xmit)
             End
             x = Msg('off')
             Address TSO "FREE F(SYSIN)"
             Address TSO "FREE F(SYSPRINT)"
             Address TSO "FREE F(SYSUT4)"
             Address TSO "FREE F(OUTDD)"
             Address TSO "FREE F(INDD)"
             Address TSO "FREE F(SEQFILE)"
             x = Msg('on')
             Call ExitProc(8)
           End

           x = Msg('off')
           Address TSO "FREE F(SYSIN)"
           Address TSO "FREE F(SYSPRINT)"
           Address TSO "FREE F(SYSUT4)"
           Address TSO "FREE F(OUTDD)"
           Address TSO "FREE F(INDD)"
           Address TSO "FREE F(SEQFILE)"
           Address TSO "DELETE '"TempDSN"'"
           x = msg('on')
        End
      End
   End

Return

UnZip_it :

   parse arg zipname

   stdout.0 = 0
   stderr.0 = 0
   /* zip up the new one     */
   shellcmd='cd "'ziploc'";pax -r -vf "'zipname'"'

   sh_rc = bpxwunix(shellcmd,,stdout.,stderr.)
   If stderr.0 > 0 Then
   Do
      Do e = 1 to stderr.0
         /* Skip printing FSUM7458 messages from pax */
         if (pos("FSUM7458 pax:",stderr.e) = 0) then
                Say stderr.e
      End
   End
   If stdout.0 > 0 Then
   Do
      Say '---STDOUT---'
      Do o = 1 to stdout.0
         Say stdout.o
      End
   End
   If sh_rc /= 0 Then
      Call Exitproc(sh_rc)

Return

Proc_Action:

  Select;
    When (Action = 'Empty') Then
      Nop
    When (Action = 'Delete' | Action = 'DELETE') Then
    Do
      var = "'"DeplDSN"'"
      ListdsiRC = Listdsi(var directory)
      If ListdsiRC <= 4 Then
      Do
        If SYSMEMBERS = 0 | sequential Then
        Do
          /* BUZD139 */
          /* Say "Deleting data set "DeplDSN" as it did not exist "||, */
          /*    "before deploy" */
          BUZMARG1 = DeplDSN
          Address ISPEXEC 'GETMSG MSG(BUZD139) LONGMSG(BUZLNGER)'
          Say BUZLNGER
          Address TSO "DELETE '"DeplDSN"'"
        End
      End
    End
    Otherwise
    Do
      /* There should be a XMI file to receive if the dataset is    */
      /* not already in the map.                                    */
      found = 0
      If sequential then
        Type = 'Type=sequential'
      Else
        Type = 'Type=PDS'

      RecvMapValue = 'RecvDSN='Strip(DataSet)' DeployTo='Strip(DeplDSN) Type
      Do z = 1 to RecvMap.0
        If RecvMap.z = RecvMapValue Then
        Do
          found = 1
        End
      End
      If found = 0 Then
      Do
        k = k + 1
        RecvMap.k = RecvMapValue
        RecvMap.k.MemList.0 = memberlist.0
        do l = 1 to memberlist.0
           RecvMap.k.MemList.l = memberlist.l
        end
        RecvMap.0 = k
      End
    End
  End

Return

ISPFErr :

   Parse arg msg 'rc='ISPFrc

   /* If the message contains a data set name  */
   /* then parse it out and read it to display */
   /* the contents                             */

   /* Say msg || ' Return code : 'ISPFrc */
   Say msg
   Say ZERRMSG ':' ZERRSM
   If Length(msg) > 70 Then
   Do
     Parse var ZERRLM msgpart 70 msg
     Say msgpart
   End
   Say msg
   Say ' '

   Parse var ZERRLM . 'data set ' msgdsn .
   msgdsn = strip(msgdsn,'t','.')
   Address ISPEXEC "DSINFO DATASET('"msgdsn"')"
   If (rc = 0) then
   Do
     Address TSO "ALLOC F(MSGDSN) DA('"msgdsn"') SHR"
     Address TSO "EXECIO * DISKR MSGDSN (STEM msgline. FINIS "
     Address TSO "FREE  F(MSGDSN)"
     If rc = 0 Then
     Do
       Do i = 1 to msgline.0
         Say msgline.i
       End
     End
   End

   Call Exitproc(ISPFrc)

Return

chkmem1: Procedure

  /* change characters that may cause problems in the xml */

  Parse arg member
  Validchars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ@#$'
  newMemb = ''

  Do mm = 1 to Length(member)
    char = Substr(member,mm,1)
    If Pos(char,Validchars) = 0 Then
    Do
      newMemb = newMemb||'HexValueIs'||right(C2D(char),3,0)
    End
    Else
      newMemb = newMemb||char
  End

Return newMemb

chkmem2: Procedure

  /* change characters to wildcards for IEBCOPY           */

  Parse arg member
  Validchars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ@#$'
  newMemb = ''

  Do mm = 1 to Length(member)
    char = Substr(member,mm,1)
    If Pos(char,Validchars) = 0 Then
      newMemb = newMemb||'%'
    Else
      newMemb = newMemb||char
  End

Return newMemb

chkmem3: Procedure

  /* change characters that may cause problems in the xml */

  Parse arg member
  nonValid = 'HexValueIs'
  newMemb = ''

  Do mm = 1 to Length(member)
    char = Substr(member,mm,10)
    If char = nonValid Then
    Do
       newMemb = newMemb || D2C(Substr(member,mm+10,03))
       mm = mm + 12
    End
    Else
      newMemb = newMemb||Substr(member,mm,1)
  End

Return newMemb

ExitProc :

   Parse arg exit_rc

   ZISPFRC = exit_rc
   Address ISPEXEC "VPUT (ZISPFRC) SHARED"

Exit exit_rc

Uninstall :

   /* Read the uninstall file and get the list of timestamps to restore */
   uninstalllist.0 = 0
   Address syscall "readfile (uninstallFile) uninstalllist."
   If retval < 0 Then
   Do
      /* BUZD109 */
      /* Say "Problem reading manifest file : "manifest". " ||, */
      /*     "Errno : "errno" Reason : "right(errnojr,8,0) */
      BUZMARG1 = manifest
      BUZMARG2 = errno
      BUZMARG3 = right(errnojr,8,0)
      Address ISPEXEC 'GETMSG MSG(BUZD109) LONGMSG(BUZLNGER)'
      Say BUZLNGER
      Call Exitproc(8)
   End

   Do q = 1 to uninstalllist.0
      Parse var uninstalllist.q Prop'='PropValue
      If Prop = 'team.deploy.common.deployTimestamps' Then
      Do
         ziplocoriginal = ziploc
         Parse var PropValue timestamp','PropValue
         do while PropValue /= ''
            ziploc = ziplocoriginal'/'timestamp
            manifest = ziploc'/rollbackManifest.xml'
            Call initialize
            Call setdsnsV301
            Call deploy

            Parse var PropValue timestamp','PropValue
         End

         If timestamp /= '' then do
            ziploc = ziplocoriginal'/'timestamp
            manifest = ziploc'/rollbackManifest.xml'
            Call initialize
            Call setdsnsV301
            Call deploy
         End
      End
   End

Return
