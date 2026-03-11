CREATE DATABASE HumanitarianProgramDB;

USE HumanitarianProgramDB;

CREATE TABLE jurisdiction_hierarchy(
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(30) NOT NULL UNIQUE,
    level VARCHAR(20) NOT NULL,
    parent VARCHAR(30),
    
    CHECK (level IN ('County','Sub-County','Village')),
    
    FOREIGN KEY (parent) 
    REFERENCES jurisdiction_hierarchy(name)
    ON DELETE CASCADE
);

CREATE TABLE village_locations(
    village_id INT AUTO_INCREMENT PRIMARY KEY,
    village VARCHAR(30) NOT NULL UNIQUE,
    total_population INT NOT NULL,
    
    CHECK (total_population >= 0),
    
    FOREIGN KEY (village)
    REFERENCES jurisdiction_hierarchy(name)
    ON DELETE CASCADE
);

CREATE TABLE beneficiary_partner_data(
    partner_id INT AUTO_INCREMENT PRIMARY KEY,
    partner VARCHAR(30) NOT NULL,
    village VARCHAR(30) NOT NULL,
    beneficiaries INT NOT NULL,
    beneficiary_type VARCHAR(30) NOT NULL,
    
    CHECK (beneficiaries >= 0),
    CHECK (beneficiary_type IN ('Individuals','Households')),
    
    FOREIGN KEY (village)
    REFERENCES village_locations(village)
    ON DELETE CASCADE
);

INSERT INTO jurisdiction_hierarchy (name, level, parent) 
VALUES
('Nairobi','County',NULL),
('Kiambu','County',NULL),
('Mombasa','County',NULL),

('Westlands','Sub-County','Nairobi'),
('Kasarani','Sub-County','Nairobi'),
('Lari','Sub-County','Kiambu'),
('Gatundu South','Sub-County','Kiambu'),
('Kisauni','Sub-County','Mombasa'),
('Likoni','Sub-County','Mombasa'),

('Parklands','Village','Westlands'),
('Kangemi','Village','Westlands'),
('Roysambu','Village','Kasarani'),
('Githurai','Village','Kasarani'),
('Kiamwangi','Village','Lari'),
('Lari Town','Village','Lari'),
('Kamwangi','Village','Gatundu South'),
('Kisauni Town','Village','Kisauni'),
('Mtopanga','Village','Kisauni'),
('Likoni Town','Village','Likoni'),
('Shika Adabu','Village','Likoni');

INSERT INTO village_locations (village,total_population) VALUES
('Parklands',15000),
('Kangemi',18000),
('Roysambu',13000),
('Githurai',12500),
('Kiamwangi',12800),
('Lari Town',9485),
('Kamwangi',5212),
('Kisauni Town',20500),
('Mtopanga',15500),
('Likoni Town',12000),
('Shika Adabu',9000);

INSERT INTO beneficiary_partner_data 
(partner,village,beneficiaries,beneficiary_type) VALUES
('IRC','Parklands',1450,'Individuals'),
('NRC','Parklands',50,'Households'),
('SCI','Kangemi',1123,'Individuals'),
('IMC','Kangemi',1245,'Individuals'),
('CESVI','Roysambu',5200,'Individuals'),
('IMC','Githurai',70,'Households'),
('IRC','Githurai',2100,'Individuals'),
('SCI','Kiamwangi',1800,'Individuals'),
('IMC','Lari Town',1340,'Individuals'),
('CESVI','Kamwangi',55,'Households'),
('IRC','Kisauni Town',4500,'Individuals'),
('SCI','Kisauni Town',1670,'Individuals'),
('IMC','Mtopanga',1340,'Individuals'),
('CESVI','Likoni Town',4090,'Individuals'),
('IRC','Shika Adabu',2930,'Individuals'),
('SCI','Shika Adabu',5200,'Individuals');


SELECT partner, SUM(
    CASE
        WHEN beneficiary_type = 'Households'
        THEN beneficiaries * 6
        ELSE beneficiaries
    END
) AS total_beneficiaries
FROM beneficiary_partner_data
GROUP BY partner;

SELECT partner, COUNT(DISTINCT village) AS villages_served
FROM beneficiary_partner_data
GROUP BY partner;

SELECT village, AVG(
CASE
    WHEN beneficiary_type='Households'
    THEN beneficiaries*6
    ELSE beneficiaries
END
) AS avg_beneficiaries
FROM beneficiary_partner_data
GROUP BY village;

SELECT partner, SUM(
CASE
WHEN beneficiary_type='Households'
THEN beneficiaries*6
ELSE beneficiaries
END
) AS total_served
FROM beneficiary_partner_data
GROUP BY partner
HAVING total_served > 5000;

SELECT village, COUNT(DISTINCT partner) AS partners
FROM beneficiary_partner_data
GROUP BY village
HAVING partners > 1;


SELECT b.village, SUM(
CASE
WHEN beneficiary_type='Households'
THEN beneficiaries*6
ELSE beneficiaries
END
) AS total_beneficiaries,
v.total_population,
ROUND(
SUM(
CASE
WHEN beneficiary_type='Households'
THEN beneficiaries*6
ELSE beneficiaries
END
) / v.total_population * 100,2
) AS coverage_percentage
FROM beneficiary_partner_data b
JOIN village_locations v
ON b.village = v.village
GROUP BY b.village,v.total_population;

SELECT village, partner
FROM beneficiary_partner_data

UNION

SELECT village, 'No Partner'
FROM village_locations
WHERE village NOT IN (
SELECT village FROM beneficiary_partner_data
);

SELECT village
FROM (
    SELECT b.village, SUM(
        CASE
        WHEN beneficiary_type='Households'
        THEN beneficiaries*6
        ELSE beneficiaries
        END
    ) / v.total_population AS coverage
    FROM beneficiary_partner_data b
    JOIN village_locations v
    ON b.village = v.village
    GROUP BY b.village,v.total_population
) AS village_coverage

WHERE coverage >
(
SELECT AVG(coverage)
FROM (
    SELECT SUM(
        CASE
        WHEN beneficiary_type='Households'
        THEN beneficiaries*6
        ELSE beneficiaries
        END
    ) / v.total_population AS coverage
    FROM beneficiary_partner_data b
    JOIN village_locations v
    ON b.village = v.village
    GROUP BY b.village,v.total_population
) avg_cov
);

WITH district_summary AS (
SELECT jh.parent AS district, SUM(
CASE
WHEN beneficiary_type='Households'
THEN beneficiaries*6
ELSE beneficiaries
END
) AS total_beneficiaries
FROM beneficiary_partner_data b
JOIN jurisdiction_hierarchy jh
ON b.village = jh.name
GROUP BY jh.parent
)

SELECT district, total_beneficiaries,
RANK() OVER (ORDER BY total_beneficiaries DESC) AS rank_position
FROM district_summary;


SELECT partner, SUM(
CASE
WHEN beneficiary_type='Households'
THEN beneficiaries*6
ELSE beneficiaries
END
) AS total_beneficiaries,

RANK() OVER(
ORDER BY SUM(
CASE
WHEN beneficiary_type='Households'
THEN beneficiaries*6
ELSE beneficiaries
END
) DESC
) AS ranking

FROM beneficiary_partner_data
GROUP BY partner;

CREATE VIEW district_summary AS
SELECT jh.parent AS district,
SUM(
CASE
WHEN beneficiary_type='Households'
THEN beneficiaries*6
ELSE beneficiaries
END
) AS total_beneficiaries
FROM beneficiary_partner_data b
JOIN jurisdiction_hierarchy jh
ON b.village = jh.name
GROUP BY jh.parent;


CREATE VIEW partner_summary AS
SELECT
partner,
COUNT(DISTINCT village) AS villages_served,
SUM(
CASE
WHEN beneficiary_type='Households'
THEN beneficiaries*6
ELSE beneficiaries
END
) AS total_beneficiaries
FROM beneficiary_partner_data
GROUP BY partner;

DELIMITER //

CREATE TRIGGER prevent_negative_beneficiaries
BEFORE INSERT ON beneficiary_partner_data
FOR EACH ROW
BEGIN

IF NEW.beneficiaries < 0 THEN
SIGNAL SQLSTATE '45000'
SET MESSAGE_TEXT = 'Beneficiaries cannot be negative';

END IF;

END 

DELIMITER //;

DELIMITER //

CREATE TRIGGER log_new_partner_entry
AFTER INSERT ON beneficiary_partner_data
FOR EACH ROW
BEGIN

INSERT INTO log_table(message)
VALUES(CONCAT('New record added for  ',NEW.partner));

END //

DELIMITER ;

DELIMITER //

CREATE TABLE log_table(
id INT AUTO_INCREMENT PRIMARY KEY,
message VARCHAR(255),
log_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER log_new_partner_entry
AFTER INSERT ON beneficiary_partner_data
FOR EACH ROW
BEGIN

INSERT INTO log_table(message)
VALUES(CONCAT('New record added for partner ',NEW.partner));

END //

DELIMITER ;

DELIMITER //

CREATE PROCEDURE GetPartnerReport(IN partner_name VARCHAR(30))

BEGIN

SELECT partner, COUNT(DISTINCT village) AS villages_served, SUM(
CASE
WHEN beneficiary_type='Households'
THEN beneficiaries*6
ELSE beneficiaries
END
) AS total_beneficiaries

FROM beneficiary_partner_data

WHERE partner = partner_name

GROUP BY partner;

END //

DELIMITER ;

CALL GetPartnerReport('IRC');

DELIMITER //

CREATE PROCEDURE GetDistrictImpact(IN district_name VARCHAR(30))

BEGIN

SELECT
jh.parent AS district,
SUM(
CASE
WHEN beneficiary_type='Households'
THEN beneficiaries*6
ELSE beneficiaries
END
) AS total_beneficiaries

FROM beneficiary_partner_data b

JOIN jurisdiction_hierarchy jh
ON b.village = jh.name

WHERE jh.parent = district_name

GROUP BY jh.parent;

END //

DELIMITER ;

SELECT partner, COUNT(DISTINCT village) AS villages
FROM beneficiary_partner_data
GROUP BY partner
HAVING villages > 3;


SELECT jh.parent AS district, SUM(
CASE
WHEN beneficiary_type='Households'
THEN beneficiaries*6
ELSE beneficiaries
END
) AS total
FROM beneficiary_partner_data b
JOIN jurisdiction_hierarchy jh
ON b.village = jh.name
GROUP BY jh.parent
HAVING total > 10000;
