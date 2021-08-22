/*Все операции и команды выполнялись под, в ручную созданным пользователем "Mikhail", c различными привелегиями на создание сессий, таблиц, процедур, функций, триггеров и тд. */
--Дроп текущих таблиц, функций и представления

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

--Была дана xls-выгрузка из АС Кредитования, данные из xls файла были преобразованы в 4 текстовых файла формата csv с разделителем ";", стандартными средствами Microsoft Exel
--Далее, была создана директория для файлов, так же были даны права на чтение и запись, все данные были из csv были загружены во внешние таблицы  с помощью Oracle SQL Loader

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
--Переносим данные из внених таблиц в обычные и организуем взаимосвязи между ними
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


/*ДЛЯ СОЗДАНИЯ ОТНОШЕНИЯ ОДИН КО МНОГИМ ЗАДАДИМ ПЕРВИЧНЫЙ КЛЮЧ ПО ТРЁМ ПОЛЯМ, ТК ИХ КОМБИНАЦИЯ УНИКАЛЬНА, В ОТЛИИЧИ ОТ ПОЛЯ COLLECTION_ID 
ПРОБЛЕМА В ТОМ ЧТО ВО ВНЕШНЕМ КЛЮЧЕ ИЗ PR_CRED ДОЛЖНО БЫТЬ ТАКОЕ ЖЕ КОЛЛИЧЕСТВО ПОЛЕЙ ЧТО И СОСТАВНОМ КЛЮЧЕ PLAN_OPER И FACET_OPER
еДИНСТВЕННЫЙ ВАРИАНТ ОБОЙТИ ПРОБЛЕМУ ЭТО ССЫЛАТЬСЯ ИЗ PLAN_OPER И FACET_OPER НА ПОЛЯ COLLECT_PLAN И COLLECT_FACT PR_CRED ТК ОНИ УНИКАЛЬНЫ!*/
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
--функция для  расчёта остатка ссудной задолженности
CREATE OR REPLACE  function LOAN_DEBT
(
    CLIENT_ID  in NUMBER,
    DOG_NUMBER in VARCHAR2,
    CURRENT_DATE in DATE
    
)
RETURN NUMBER
is
RES NUMBER := 0;                                     /*возвращаем разницу между сумму фактических погашений и суммой кредита */
begin
    with AMOUNT_PAYMENTS as                          /*используем для удобства псевдоним для запроса которым подсчитываем сумму фактических погашений */
    (                                                /* далее для большей читаемости кода даём псевдонимы полям, но так как алиас уже использован в операторе with, ключевое слово as опушено */
        select    PR.NUM_DOG  ND, 
                  sum(FO.F_SUM) CL_SUM       
        from      FACT_OPER FO, 
                  PR_CRED   PR           
        where     FO.COLLECTION_ID = PR.COLLECT_FACT /*проверяем что операция принадлежит опеределённому клиенту*/
              and FO.TYPE_OPER = 'Погашение кредита' /*выбираем только операции погашения кредита*/
              and FO.F_DATE <= TO_DATE(CURRENT_DATE) /*проверяем что дата платежа меньше даты отчёта*/
        group by  PR.NUM_DOG                         /*в group by все поля кроме агрегатных функций */
    )
    /*Считаем разниму между суммой заёма и суммой фактических погашений */
        select (FO.F_SUM - A.CL_SUM) into RES -- summa, res
        from      FACT_OPER FO,
                  PR_CRED   PR, 
                  AMOUNT_PAYMENTS A
        where     FO.COLLECTION_ID = PR.COLLECT_FACT /*проверяем что операция принадлежит опеределённому клиенту*/
              and PR.NUM_DOG = A.ND                  /*номера договора должны совпадать для корректного расчёта разности*/
              and FO.TYPE_OPER = 'Выдача кредита'    /*выбираем только операции выдача кредита*/
              and FO.F_DATE <= to_date(CURRENT_DATE) /*проверяем что дата платежа меньше даты отчёта*/
              and PR.ID_CLIENT = CLIENT_ID           /*проверяем клиентский идентификатор*/
              and PR.NUM_DOG = DOG_NUMBER;           /*проверяем номер договора*/
    
        RETURN RES; 

/*Обрабатываем возможные ошибки встроенным исключениями
Была попытка написать собственный exception, но возникли трудности*/
        EXCEPTION
        when NO_DATA_FOUND then
            dbms_output.put_line('Нет данных!');
        when INVALID_NUMBER then
            dbms_output.put_line('Ошибка числовых данных!');    
        when VALUE_ERROR then
            dbms_output.put_line('Ошибка преобразования числовых или символьных данных!'); 
     
end;
/

--функция для подсчёта суммы предстоящих процентов
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
    where     PO.COLLECTION_ID = PR.COLLECT_PLAN   /*проверяем что операция принадлежит опеределённому клиенту*/
          and PO.TYPE_OPER = 'Погашение процентов' /*выбираем только операции погашение процентов*/
          and PO.P_DATE <= TO_DATE(CURRENT_DATE)   /*проверяем что плановаядата платежа меньше даты отчёта*/
          and PR.ID_CLIENT = CLIENT_ID             /*проверяем клиентский идентификатор*/
          and PR.NUM_DOG = DOG_NUMBER              /*проверяем номер договора*/
    group by  PR.NUM_DOG;

    select    sum(FO.F_SUM) into FACT_PERC
    from      FACT_OPER FO, PR_CRED PR
    where     FO.COLLECTION_ID = PR.COLLECT_FACT   /*проверяем что операция принадлежит опеределённому клиенту*/
          and FO.TYPE_OPER = 'Погашение процентов' /*выбираем только операции погашение процентов*/
          and FO.F_DATE <= TO_DATE(CURRENT_DATE)   /*проверяем что фактическая дата платежа меньше даты отчёта*/
          and PR.ID_CLIENT = CLIENT_ID             /*проверяем клиентский идентификатор*/
          and PR.NUM_DOG = DOG_NUMBER              /*проверяем номер договора*/
    group by  PR.NUM_DOG;
    return   (PLAN_PERC - FACT_PERC);              /*возвращаем разницу*/
    
/*Обрабатываем возможные ошибки встроенным исключениями
Была попытка написать собственный exception, но возникли трудности*/
    EXCEPTION
    when NO_DATA_FOUND then
        dbms_output.put_line('Нет данных!');
    when INVALID_NUMBER then
        dbms_output.put_line('Ошибка числовых данных!');    
    when VALUE_ERROR then
        dbms_output.put_line('Ошибка преобразования числовых или символьных данных!');   
end;
/
            
            
/*создаём представление для того что бы постороить отчёт о состоянии кредитного портфеля 
для корректного именования полей, так же используем алиасы не указывая ключевое слово as, тк оно уже есть в конструкции*/           
CREATE OR REPLACE  view LOAN_REPORT as
select  
        PR.NUM_DOG НОМЕР_ДОГОВОРА, 
        CLI.CL_NAME ФИО_КЛИЕНТА,
        PR.SUMMA_DOG СУММА_ДОГОВОРА, 
        PR.DATE_BEGIN ДАТА_НАЧАЛА, 
        PR.DATE_END ДАТА_ОКОНЧАНИЯ, 
        LOAN_DEBT (CLI.ID, PR.NUM_DOG, SYSDATE) РАСЧЁТ_ССУДНОЙ_ЗАДОЛЖЕННОСТИ,
        AMOUNT_PERCENT (CLI.ID, PR.NUM_DOG, SYSDATE) СУММА_ПРЕДСТОЯЩИХ_К_ПОГАШЕНИЮ_ПРОЦЕНТОВ,
        TO_CHAR(SYSDATE, 'dd.mm.yy hh24:mi:ss') ВРЕМЯ_СОЗДАНИЯ_ОТЧЁТА
from
        PR_CRED PR, 
        CLIENTS CLI
where   PR.ID_CLIENT = CLI.ID;

/*Выводим отчёт о состоянии кредитного портфеля на текущую дату, так же можно проверить что данные выводятся, только по тем договорам у которых
дата начала действия меньше даты отчёта/*
select * from LOAN_REPORT 
where ДАТА_НАЧАЛА < '09.09.20';
-----------------------------------------------------------------------------


/*Из не реализованного, была попытка написать функцию которая возвращает несколько полей таблицы, для этого был создан табличный тип данных
но возникла ошибка типизации, на сколько мне известно, подобные манипуляции можно было бы сделать испульзовав курсоры и цикл forall, но попытки не дали результата, в виду 
отсутствия опыта, хотя подобная реализация могла бы быть гораздо более производительной, чем текущая к тому же можно было бы проще манипулировать датой.
Так же для вывода отчёта в файл скорее всего стоило воспользоваться курсорами, добиться работоспособности не удалось, попытка использовать spool так же не завершилась успехом./*
