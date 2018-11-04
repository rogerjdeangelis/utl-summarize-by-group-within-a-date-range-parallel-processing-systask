Summarize by group within a date range parallel processing systask

  Two Solutions

        1. Single Task
        2. Four parallel batch tasks

Problem: Join hav1st to hav2nd on org and sum amt when 0 <comDte-subDte < 6 months

For Parallel processing

Split the input data into 4 mutally exclusive pieces and run in parallel.
If you know your data you can outperform Teradata and Exadata.
see comments on end.

Because this solution is so I/O bound you do need a partitioned robust I/O Subsystem.
Otherwise run just one task.
Should be more effective if you have to sort the tables.

INPUT
=====

SD1.HAV1ST total obs=4 (SAS date expressed as numeric)

 ORG    SUBDTE

 A12     20093
 B22     20120
 B22     20139
 F02     20157


SD1.HAV2ND total obs=6

  ORG    COMDTE      AMT

  A12     20188      100
  B22     20193      200
  B22     20194       50
  B22     20376      879
  C50     20209      258
  D15     20100     1589


RULES
-----

 SD1.ABCDEFGH   + RULES Join and sum within date range
                |
                |        Filter by group(org)
                |
 ORG    AMTSUM  | 0 <comDte-subDte  < 6 months    Amt
                |
 A12     100    | 0 <20188-20098=90 < 6 months    100

 B22     250    |  20194-20120=  74 < 6 months    200
                   20223-20139 =237 < 6 months     50
                                                  ---
                                                  250
 C50       0    |
 D15       0    +


EXAMPLE OUTPUT
--------------

WORK.WANT_A_G total obs=4

  ORG    AMTSUM

  A12      100
  B22      250
  C50        0
  D15        0

PROCESS
=======

 1. Single Task
 --------------

    libname sd1 "d:/sd1";

    data want_a_g(KEEP=org amtSum);
      retain org '        ' amtSum 0;
      merge
        sd1.hav1st(in=big)
        sd1.hav2nd(in=ltl);
      by org;
      if ltl;
      if 0 < INTCK('month',subDte, comDte) < 6 then amtSum=amtSum+amt;
      if last.org then do;
         output;
         amtSum=0;
      end;
    ;run;quit;


 2. Four parallel batch tasks
 -----------------------------

    * for development if you rerun;
    proc datasets lib=sd1;
     delete ABCDEFG;
    run;quit;

    * save in your autocall library;
    data _null_;file "c:\oto\ltrcut.sas" lrecl=512;input;put _infile_;putlog _infile_;
    cards4;
    %macro ltrCut(letters);
    libname sd1 "d:/sd1";
    data sd1.&letters.(keep=org amtSum);
      retain org '   ' amtSum 0;
      merge
        sd1.hav1st(in=big where=(indexc(substr(org,1,1),"&letters")>0))
        sd1.hav2nd(in=ltl where=(indexc(substr(org,1,1),"&letters")>0));
      by org;
      if ltl;
      if 0 < INTCK('month',subDte, comDte) < 6 then amtSum=amtSum+amt;
      if last.org then do;
         output;
         putlog org= amtSum=;
         amtSum=0;
      end;
    ;run;quit;
    %mend ltrCut;
    ;;;;
    run;quit;

    /*
    * check interactively;
    %ltrCut(ABCDEFG);
    proc print data=sd1.ABCDEFG;
    run;quit;
    */

    %let _s=%sysfunc(compbl(C:\Progra~1\SASHome\SASFoundation\9.4\sas.exe -sysin
     c:\nul -sasautos c:\oto -autoexec c:\oto\Tut_Oto.sas -work d:\wrk));

    * The argument of getmode is the remainder after dividing by 8;

    options noxwait noxsync;
    %let tym=%sysfunc(time());
    systask kill sys1 sys2 sys3 sys4;
    systask command "&_s -termstmt %nrstr(%ltrCut(ABCDEFG);) -log d:\log\a1.log" taskname=sys1;
    systask command "&_s -termstmt %nrstr(%ltrCut(HIJKLMN);) -log d:\log\a2.log" taskname=sys2;
    systask command "&_s -termstmt %nrstr(%ltrCut(OPQRSTU);) -log d:\log\a3.log" taskname=sys3;
    systask command "&_s -termstmt %nrstr(%ltrCut(VWXYZ);) -log d:\log\a4.log" taskname=sys4;
    waitfor sys1 sys2 sys3 sys4;
    %put %sysevalf( %sysfunc(time()) - &tym);

    * keep as view;
    data want_parallel/view=want_parallel;
       set
           sd1.ABCDEFG
           sd1.HIJKLMN
           sd1.OPQRSTU
           sd1.VWXYZ
       ;
    run;quit;


    LOG
    ---

    NOTE: AUTOEXEC processing completed.

    NOTE: Libref SD1 was successfully assigned as follows:
          Engine:        V9
          Physical Name: d:\sd1

    ORG=A12 AMTSUM=100
    ORG=B22 AMTSUM=250
    ORG=C50 AMTSUM=0
    ORG=D15 AMTSUM=0

    NOTE: MERGE statement has more than one data set with repeats of BY values.
    NOTE: Missing values were generated as a result of performing an operation on missing values.
          Each place is given by: (Number of times) at (Line):(Column).
          2 at 1:218
    NOTE: There were 4 observations read from the data set SD1.HAV1ST.
          WHERE INDEXC(SUBSTR(org, 1, 1), 'ABCDEFG')>0;
    NOTE: There were 6 observations read from the data set SD1.HAV2ND.
          WHERE INDEXC(SUBSTR(org, 1, 1), 'ABCDEFG')>0;
    NOTE: The data set SD1.ABCDEFG has 4 observations and 2 variables.
    NOTE: DATA statement used (Total process time):
          real time           0.01 seconds
          cpu time            0.00 seconds


*                _               _       _
 _ __ ___   __ _| | _____     __| | __ _| |_ __ _
| '_ ` _ \ / _` | |/ / _ \   / _` |/ _` | __/ _` |
| | | | | | (_| |   <  __/  | (_| | (_| | || (_| |
|_| |_| |_|\__,_|_|\_\___|   \__,_|\__,_|\__\__,_|

;


libname sd1 "d:/sd1";

* large table;
data sd1.hav1st;
input Org$ subDte MMDDYY8.;
cards4;
A12 01052015
B22 02012015
B22 02202015
F02 03102015
;;;;
run;quit;

* small table;
data sd1.hav2nd;
   input Org$ comDte MMDDYY8. Amt;
cards4;
A12 04102015 100
B22 04152015 200
B22 04162015 50
B22 12152015 879
C50 05012015 258
D15 01122015 1589
;;;;
run;quit;


COMMENTS
========

Summarize by Group Within a Date Range

Really need to know more about the data structure

   1. Are organization_ids uniformly distributed
   2. Relative size of tables
   3. Cardinality of organization_id (index under some conditions)
   4. Bandwith of you I/O subsystem
      (Inexpensive Intel Gen1 off lease server converted to workstation $400)
   5. Any other useful splitting variables
   6. Can description be moved to a dimension table and joined back as needed
   7. Since you do not have description on the final table I will drop it.

You really should use a separate dimension table for description or use a format.
Dragging that long description around will be fime consuming.

I am going to run 4 parallel tasks based on splitting orgaization_id.
Using the first character of organization_id I am going to
assume a max on 26 sets of orgaization ids.
I also assume organization_id is not heavily skewed,
If you know the frequencies of organization_id you can make better uniform splits.
There are many ways to create mutually exclusive splits.
The mod function works will with large integer ids.
I am also going to assume you have reasonable 'partitioning
software like SPDE(free wirh SAS workstation), EXADATA ot TERADATA.




