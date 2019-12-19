CREATE TABLE IF NOT EXISTS `feriados`
(
    `data`   DATE         NOT NULL,
    `titulo` varchar(255) NOT NULL,
    PRIMARY KEY (`data`)
);

CREATE TABLE IF NOT EXISTS `feriados_fixos`
(
    `mes`    INT(2)       NOT NULL,
    `dia`    INT(2)       NOT NULL,
    `titulo` varchar(255) NOT NULL,
    PRIMARY KEY (`mes`, `dia`)
);

CREATE TABLE IF NOT EXISTS `feriados_moveis`
(
    `dias`   INT(2)       NOT NULL,
    `titulo` varchar(255) NOT NULL,
    PRIMARY KEY (`dias`)
);

DROP FUNCTION IF EXISTS f_easter;

DELIMITER //
CREATE FUNCTION f_easter(
    p_year YEAR
)
    RETURNS VARCHAR(255)
    DETERMINISTIC
    NO SQL
    COMMENT 'Calculates easter day for a given year.'
BEGIN
    --
    -- code taken from
    -- http://en.wikipedia.org/wiki/Computus#Anonymous_Gregorian_algorithm
    --
    DECLARE a SMALLINT DEFAULT p_year % 19;
    DECLARE b SMALLINT DEFAULT p_year DIV 100;
    DECLARE c SMALLINT DEFAULT p_year % 100;
    DECLARE d SMALLINT DEFAULT b DIV 4;
    DECLARE e SMALLINT DEFAULT b % 4;
    DECLARE f SMALLINT DEFAULT (b + 8) DIV 25;
    DECLARE g SMALLINT DEFAULT (b - f + 1) DIV 3;
    DECLARE h SMALLINT DEFAULT (19 * a + b - d - g + 15) % 30;
    DECLARE i SMALLINT DEFAULT c DIV 4;
    DECLARE k SMALLINT DEFAULT c % 4;
    DECLARE L SMALLINT DEFAULT (32 + 2 * e + 2 * i - h - k) % 7;
    DECLARE m SMALLINT DEFAULT (a + 11 * h + 22 * L) DIV 451;
    DECLARE v100 SMALLINT DEFAULT h + L - 7 * m + 114;

    RETURN STR_TO_DATE(CONCAT(p_year, '-', v100 DIV 31, '-', (v100 % 31) + 1), '%Y-%c-%e');
END;
//
DELIMITER ;

/* feriados fixos nacionais */
INSERT INTO `feriados_fixos` (`dia`, `mes`, `titulo`) VALUES
    (1, 1, 'Confraternização Universal'),
    (21, 4, 'Tiradentes'),
    (1, 5, 'Dia do Trabalhador'),
    (7, 9, 'Independência do Brasil'),
    (12, 10, 'Nossa Senhora Aparecida'),
    (2, 11, 'Finados'),
    (15, 11, 'Proclamação da República'),
    (25, 12, 'Natal');

/* feriados móveis com base na data da Páscoa */
INSERT INTO `feriados_moveis` (`dias`, `titulo`) VALUES
    (-47, 'Carnaval'),
    (-2, 'Paixão de Cristo'),
    (60, 'Corpus Christi');

drop procedure if exists p_preencher_feriados;

DELIMITER //
create procedure p_preencher_feriados(p_year YEAR)
    COMMENT 'Preencher a tabela de feriados com os feriados recorrentes'
BEGIN
    INSERT INTO feriados (data, titulo)
        SELECT STR_TO_DATE(CONCAT(p_year, '-', ff.mes, '-', ff.dia), '%Y-%c-%e'), ff.titulo FROM feriados_fixos ff
        ON DUPLICATE KEY UPDATE titulo = ff.titulo;

    INSERT INTO feriados (data, titulo)
        SELECT DATE_ADD(f_easter(p_year), interval fm.dias DAY), fm.titulo FROM feriados_moveis fm
        ON DUPLICATE KEY UPDATE titulo = fm.titulo;
end;
//
DELIMITER ;

/* exemplo */
call p_preencher_feriados(2019);
call p_preencher_feriados(2020);




DROP FUNCTION IF EXISTS  f_dia_util;

DELIMITER //
CREATE FUNCTION f_dia_util(
    p_data DATE
)
    RETURNS INTEGER
    DETERMINISTIC
    NO SQL
    COMMENT 'Retorna se o dia é util (utiliza tabela de feriados com campo data)'
BEGIN
    Declare util Integer Default 1;
    DECLARE fer Integer default 0;
    IF WEEKDAY(p_data) in (5,6) THEN
        SET util = 0;
    end if;

    SELECT 1 INTO fer FROM feriados WHERE data=p_data;
    IF fer = 1 THEN
        SET util = 0;
    end if;
    /* retornar se está na tabela de feriados */
    return util;
END;
//
DELIMITER ;

DROP FUNCTION IF EXISTS  f_enesimo_dia_util;

DELIMITER //
CREATE FUNCTION f_enesimo_dia_util(
    p_ano INTEGER,
    p_mes INTEGER,
    p_dia INTEGER
)
    RETURNS DATE
    DETERMINISTIC
    NO SQL
    COMMENT 'Retorna o enésimo dia util do mês especificado (utiliza a função f_dia_util)'
BEGIN
    DECLARE data DATE DEFAULT STR_TO_DATE(CONCAT(p_ano,'-',p_mes,'-01'),'%Y-%c-%e');
    DECLARE a INT Default 0;

    simple_loop: LOOP
        while f_dia_util(data) = 0 do
            set data = date_add(data, interval 1 day);
        end while;

        SET a = a + 1;
        IF a = p_dia THEN
            LEAVE simple_loop;
        END IF;

        set data = date_add(data, interval 1 day);
    END LOOP simple_loop;

    return data;
END //
delimiter ;

/* exemplo */
select f_enesimo_dia_util(2019,1,5) data;
select f_dia_util('2019-01-01') util;
