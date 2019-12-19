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

/* exemplo */
call p_preencher_feriados(2019);
