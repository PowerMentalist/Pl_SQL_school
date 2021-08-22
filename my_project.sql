/*��� �������� � ������� ����������� ���, � ������ ��������� ������������� "Mikhail", c ���������� ������������ �� �������� ������, ������, ��������, �������, ��������� � ��. */
--���� ������� ������, ������� � �������������

DROP TABLE CLIENTS;
DROP TABLE FACT_OPER;
DROP TABLE PLAN_OPER;
DROP TABLE PR_CRED;
DROP TABLE CLIENTS_EXTERNAL;
DROP TABLE FACT_OPER_EXTERNAL;
DROP TABLE PLAN_OPER_EXTERNAL;
DROP TABLE PR_CRED_EXTERNAL;
DROP FUNCTION AMOUNT_PERCENT;
DROP FUNCTION LOAN_DEBT;
DROP VIEW  LOAN_REPORT;

--���� ���� xls-�������� �� �� ������������, ������ �� xls ����� ���� ������������� � 4 ��������� ����� ������� csv � ������������ ";", ������������ ���������� Microsoft Exel
--�����, ���� ������� ���������� ��� ������, ��� �� ���� ���� ����� �� ������ � ������, ��� ������ ���� �� csv ���� ��������� �� ������� �������  � ������� Oracle SQL Loader

CREATE OR REPLACE  DIRECTORY external_directory AS 'D:\oracleDB\my_files';

grant read, write on DIRECTORY external_directory to SYS;

--------------------------------------------------------------------------------
CREATE TABLE Mikhail.CLIENTS_EXTERNAL (
       ID          NUMBER,
       CL_NAME     VARCHAR2(100),
       DATE_BIRTH  DATE
)
ORGANIZATION EXTERNAL
(
    TYPE oracle_loader
    DEFAULT DIRECTORY external_directory
    ACCESS PARAMETERS 
    (
        RECORDS DELIMITED BY NEWLINE
        FIELDS TERMINATED BY ';'
        (
              ID,         
              CL_NAME,    
              DATE_BIRTH CHAR(10) DATE_FORMAT DATE MASK "dd/mm/yyyy"
        )
    )
    LOCATION ('clients.csv')
)
REJECT LIMIT UNLIMITED;

select * from CLIENTS_EXTERNAL



--------------------------------------------------------------------------------
CREATE TABLE Mikhail.FACT_OPER_EXTERNAL (
      COLLECTION_ID  NUMBER,
      F_DATE  DATE,
      F_SUM NUMBER,
      TYPE_OPER VARCHAR2(100)
)
ORGANIZATION EXTERNAL
(
    TYPE oracle_loader
    DEFAULT DIRECTORY external_directory
    ACCESS PARAMETERS 
    (
        RECORDS DELIMITED BY NEWLINE
        FIELDS TERMINATED BY ';'
        (
              COLLECTION_ID,
              F_DATE    CHAR(10) DATE_FORMAT DATE MASK "dd/mm/yyyy",
              F_SUM,  
              TYPE_OPER 
        )
    )
    LOCATION ('fact_oper.csv')
)
REJECT LIMIT UNLIMITED;

SELECT * FROM FACT_OPER_EXTERNAL



-------------------------------------------------------------
CREATE TABLE Mikhail.PLAN_OPER_EXTERNAL (
      COLLECTION_ID  NUMBER,
      P_DATE  DATE,
      P_SUM number,
      TYPE_OPER VARCHAR2(100)
)
ORGANIZATION EXTERNAL
(
    TYPE oracle_loader
    DEFAULT DIRECTORY external_directory
    ACCESS PARAMETERS 
    (
        RECORDS DELIMITED BY NEWLINE
        FIELDS TERMINATED BY ';'
        (
              COLLECTION_ID,
              P_DATE    CHAR(10) DATE_FORMAT DATE MASK "dd/mm/yyyy",
              P_SUM,   
              TYPE_OPER 
        )
    )
    LOCATION ('plan_oper.csv')
)
REJECT LIMIT UNLIMITED;

SELECT * FROM PLAN_OPER_EXTERNAL



--------------------------------------------------------------------------
CREATE TABLE Mikhail.PR_CRED_EXTERNAL (
      ID  NUMBER,
      NUM_DOG VARCHAR2(100),
      SUMMA_DOG NUMBER,
      DATE_BEGIN DATE,
      DATE_END DATE,
      ID_CLIENT NUMBER,
      COLLECT_PLAN NUMBER,
      COLLECT_FACT NUMBER
)
ORGANIZATION EXTERNAL
(
    TYPE oracle_loader
    DEFAULT DIRECTORY external_directory
    ACCESS PARAMETERS 
    (
        RECORDS DELIMITED BY NEWLINE
        FIELDS TERMINATED BY ';'
        (
          ID,
          NUM_DOG,
          SUMMA_DOG,
          DATE_BEGIN CHAR(10) DATE_FORMAT DATE MASK "dd/mm/yyyy",
          DATE_END CHAR(10) DATE_FORMAT DATE MASK "dd/mm/yyyy",
          ID_CLIENT,
          COLLECT_PLAN,
          COLLECT_FACT  
        )
    )
    LOCATION ('pr_cred.csv')
)
REJECT LIMIT UNLIMITED;

SELECT * FROM PR_CRED_EXTERNAL



--------------------------------------------------------------------------------
--��������� ������ �� ������ ������ � ������� � ���������� ����������� ����� ����
CREATE TABLE PR_CRED
(
      ID  NUMBER PRIMARY KEY,
      NUM_DOG VARCHAR2(100),
      SUMMA_DOG NUMBER,
      DATE_BEGIN DATE,
      DATE_END DATE,
      ID_CLIENT NUMBER,
      COLLECT_PLAN NUMBER UNIQUE,
      COLLECT_FACT NUMBER UNIQUE,
      FOREIGN KEY (ID_CLIENT) REFERENCES CLIENTS(ID)
);
INSERT INTO PR_CRED
SELECT * FROM PR_CRED_EXTERNAL

SELECT * FROM PR_CRED



--------------------------------------------------------------------------------
CREATE TABLE CLIENTS
(
       ID          NUMBER PRIMARY KEY,
       CL_NAME     VARCHAR2(100),
       DATE_BIRTH  DATE 
);
INSERT INTO CLIENTS
SELECT * FROM CLIENTS_EXTERNAL

SELECT * FROM CLIENTS


/*��� �������� ��������� ���� �� ������ ������� ��������� ���� �� �Ш� �����, �� �� ���������� ���������, � ������� �� ���� COLLECTION_ID 
�������� � ��� ��� �� ������� ����� �� PR_CRED ������ ���� ����� �� ����������� ����� ��� � ��������� ����� PLAN_OPER � FACET_OPER
������������ ������� ������ �������� ��� ��������� �� PLAN_OPER � FACET_OPER �� ���� COLLECT_PLAN � COLLECT_FACT PR_CRED �� ��� ���������!*/
--------------------------------------------------------------------------------
CREATE TABLE PLAN_OPER
(
      COLLECTION_ID  NUMBER ,
      P_DATE  DATE,
      P_SUM number,
      TYPE_OPER VARCHAR2(100),
      FOREIGN KEY (COLLECTION_ID) REFERENCES PR_CRED(COLLECT_PLAN)
);
INSERT INTO PLAN_OPER
SELECT * FROM PLAN_OPER_EXTERNAL

SELECT * FROM PLAN_OPER



--------------------------------------------------------------------------------
CREATE TABLE FACT_OPER
(
      COLLECTION_ID  NUMBER,
      F_DATE  DATE,
      F_SUM NUMBER,
      TYPE_OPER VARCHAR2(100),
      FOREIGN KEY (COLLECTION_ID) REFERENCES PR_CRED(COLLECT_FACT)
);
INSERT INTO FACT_OPER
SELECT * FROM FACT_OPER_EXTERNAL

SELECT * FROM FACT_OPER



--------------------------------------------------------------------------------
--������� ���  ������� ������� ������� �������������
CREATE OR REPLACE  function LOAN_DEBT
(
    CLIENT_ID  in NUMBER,
    DOG_NUMBER in VARCHAR2,
    CURRENT_DATE in DATE
    
)
RETURN NUMBER
is
RES NUMBER := 0;                                     /*���������� ������� ����� ����� ����������� ��������� � ������ ������� */
begin
    with AMOUNT_PAYMENTS as                          /*���������� ��� �������� ��������� ��� ������� ������� ������������ ����� ����������� ��������� */
    (                                                /* ����� ��� ������� ���������� ���� ��� ���������� �����, �� ��� ��� ����� ��� ����������� � ��������� with, �������� ����� as ������� */
        select    PR.NUM_DOG  ND, 
                  sum(FO.F_SUM) CL_SUM       
        from      FACT_OPER FO, 
                  PR_CRED   PR           
        where     FO.COLLECTION_ID = PR.COLLECT_FACT /*��������� ��� �������� ����������� ������������� �������*/
              and FO.TYPE_OPER = '��������� �������' /*�������� ������ �������� ��������� �������*/
              and FO.F_DATE <= TO_DATE(CURRENT_DATE) /*��������� ��� ���� ������� ������ ���� ������*/
        group by  PR.NUM_DOG                         /*� group by ��� ���� ����� ���������� ������� */
    )
    /*������� ������� ����� ������ ���� � ������ ����������� ��������� */
        select (FO.F_SUM - A.CL_SUM) into RES -- summa, res
        from      FACT_OPER FO,
                  PR_CRED   PR, 
                  AMOUNT_PAYMENTS A
        where     FO.COLLECTION_ID = PR.COLLECT_FACT /*��������� ��� �������� ����������� ������������� �������*/
              and PR.NUM_DOG = A.ND                  /*������ �������� ������ ��������� ��� ����������� ������� ��������*/
              and FO.TYPE_OPER = '������ �������'    /*�������� ������ �������� ������ �������*/
              and FO.F_DATE <= to_date(CURRENT_DATE) /*��������� ��� ���� ������� ������ ���� ������*/
              and PR.ID_CLIENT = CLIENT_ID           /*��������� ���������� �������������*/
              and PR.NUM_DOG = DOG_NUMBER;           /*��������� ����� ��������*/
    
        RETURN RES; 

/*������������ ��������� ������ ���������� ������������
���� ������� �������� ����������� exception, �� �������� ���������*/
        EXCEPTION
        when NO_DATA_FOUND then
            dbms_output.put_line('��� ������!');
        when INVALID_NUMBER then
            dbms_output.put_line('������ �������� ������!');    
        when VALUE_ERROR then
            dbms_output.put_line('������ �������������� �������� ��� ���������� ������!'); 
     
end;
/

--������� ��� �������� ����� ����������� ���������
CREATE OR REPLACE  function AMOUNT_PERCENT
(
    CLIENT_ID  in NUMBER,
    DOG_NUMBER in VARCHAR2,
    CURRENT_DATE in DATE
    
)
RETURN NUMBER
is
PLAN_PERC NUMBER := 0;  /**/
FACT_PERC NUMBER := 0;  /**/
begin
    select    sum(PO.P_SUM) into PLAN_PERC
    from      PLAN_OPER PO, 
              PR_CRED PR
    where     PO.COLLECTION_ID = PR.COLLECT_PLAN   /*��������� ��� �������� ����������� ������������� �������*/
          and PO.TYPE_OPER = '��������� ���������' /*�������� ������ �������� ��������� ���������*/
          and PO.P_DATE <= TO_DATE(CURRENT_DATE)   /*��������� ��� ������������ ������� ������ ���� ������*/
          and PR.ID_CLIENT = CLIENT_ID             /*��������� ���������� �������������*/
          and PR.NUM_DOG = DOG_NUMBER              /*��������� ����� ��������*/
    group by  PR.NUM_DOG;

    select    sum(FO.F_SUM) into FACT_PERC
    from      FACT_OPER FO, PR_CRED PR
    where     FO.COLLECTION_ID = PR.COLLECT_FACT   /*��������� ��� �������� ����������� ������������� �������*/
          and FO.TYPE_OPER = '��������� ���������' /*�������� ������ �������� ��������� ���������*/
          and FO.F_DATE <= TO_DATE(CURRENT_DATE)   /*��������� ��� ����������� ���� ������� ������ ���� ������*/
          and PR.ID_CLIENT = CLIENT_ID             /*��������� ���������� �������������*/
          and PR.NUM_DOG = DOG_NUMBER              /*��������� ����� ��������*/
    group by  PR.NUM_DOG;
    return   (PLAN_PERC - FACT_PERC);              /*���������� �������*/
    
/*������������ ��������� ������ ���������� ������������
���� ������� �������� ����������� exception, �� �������� ���������*/
    EXCEPTION
    when NO_DATA_FOUND then
        dbms_output.put_line('��� ������!');
    when INVALID_NUMBER then
        dbms_output.put_line('������ �������� ������!');    
    when VALUE_ERROR then
        dbms_output.put_line('������ �������������� �������� ��� ���������� ������!');   
end;
/
            
            
/*������ ������������� ��� ���� ��� �� ���������� ����� � ��������� ���������� �������� 
��� ����������� ���������� �����, ��� �� ���������� ������ �� �������� �������� ����� as, �� ��� ��� ���� � �����������*/           
CREATE OR REPLACE  view LOAN_REPORT as
select  
        PR.NUM_DOG �����_��������, 
        CLI.CL_NAME ���_�������,
        PR.SUMMA_DOG �����_��������, 
        PR.DATE_BEGIN ����_������, 
        PR.DATE_END ����_���������, 
        LOAN_DEBT (CLI.ID, PR.NUM_DOG, SYSDATE) ���ר�_�������_�������������,
        AMOUNT_PERCENT (CLI.ID, PR.NUM_DOG, SYSDATE) �����_�����������_�_���������_���������,
        TO_CHAR(SYSDATE, 'dd.mm.yy hh24:mi:ss') �����_��������_��ר��
from
        PR_CRED PR, 
        CLIENTS CLI
where   PR.ID_CLIENT = CLI.ID;

/*������� ����� � ��������� ���������� �������� �� ������� ����, ��� �� ����� ��������� ��� ������ ���������, ������ �� ��� ��������� � �������
���� ������ �������� ������ ���� ������/*
select * from LOAN_REPORT 
where ����_������ < '09.09.20';
-----------------------------------------------------------------------------


/*�� �� ��������������, ���� ������� �������� ������� ������� ���������� ��������� ����� �������, ��� ����� ��� ������ ��������� ��� ������
�� �������� ������ ���������, �� ������� ��� ��������, �������� ����������� ����� ���� �� ������� ����������� ������� � ���� forall, �� ������� �� ���� ����������, � ���� 
���������� �����, ���� �������� ���������� ����� �� ���� ������� ����� ����������������, ��� ������� � ���� �� ����� ���� �� ����� �������������� �����.
��� �� ��� ������ ������ � ���� ������ ����� ������ ��������������� ���������, �������� ����������������� �� �������, ������� ������������ spool ��� �� �� ����������� �������./*
