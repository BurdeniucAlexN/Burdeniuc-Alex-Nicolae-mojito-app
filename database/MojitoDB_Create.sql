-- ============================================================
--  MojitoDB — Baza de date pentru aplicatia Mojito
--  Opera Magna SRL | Proiect practica PAPP-231
--  Autor: Burdeniuc Alex-Nicolae
--  Data: Mai 2026
-- ============================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'MojitoDB')
    DROP DATABASE MojitoDB;
GO

CREATE DATABASE MojitoDB;
GO

USE MojitoDB;
GO

-- ============================================================
--  1. CATEGORII
--  tip: 'european' | 'japonez' | 'bar' | 'bauturi' | 'manual'
-- ============================================================
CREATE TABLE Categorii (
    id    INT IDENTITY(1,1) PRIMARY KEY,
    nume  NVARCHAR(100) NOT NULL,
    tip   NVARCHAR(50)  NOT NULL
);
GO

-- ============================================================
--  2. INGREDIENTE
--  unitate_masura: 'g' | 'ml' | 'buc'
-- ============================================================
CREATE TABLE Ingrediente (
    id              INT IDENTITY(1,1) PRIMARY KEY,
    nume            NVARCHAR(150) NOT NULL,
    unitate_masura  NVARCHAR(10)  NOT NULL CHECK (unitate_masura IN ('g','ml','buc'))
);
GO

-- ============================================================
--  3. STOCURI — cantitati curente pentru fiecare ingredient
-- ============================================================
CREATE TABLE Stocuri (
    id                    INT IDENTITY(1,1) PRIMARY KEY,
    id_ingredient         INT NOT NULL REFERENCES Ingrediente(id),
    cantitate_disponibila DECIMAL(10,2) NOT NULL DEFAULT 0,
    cantitate_minima      DECIMAL(10,2) NOT NULL DEFAULT 0
);
GO

-- ============================================================
--  4. PRODUSE
--  tip_scadere: 'ingrediente' | 'portie' | 'bucata' | 'premix' | 'manual'
-- ============================================================
CREATE TABLE Produse (
    id           INT IDENTITY(1,1) PRIMARY KEY,
    nume         NVARCHAR(200) NOT NULL,
    id_categorie INT           NOT NULL REFERENCES Categorii(id),
    pret         DECIMAL(10,2) NOT NULL,
    gramaj       NVARCHAR(50)  NULL,
    tip_scadere  NVARCHAR(20)  NOT NULL
        CHECK (tip_scadere IN ('ingrediente','portie','bucata','premix','manual'))
);
GO

-- ============================================================
--  5. PRODUS_INGREDIENTE — reteta fiecarui produs
-- ============================================================
CREATE TABLE Produs_Ingrediente (
    id_produs     INT           NOT NULL REFERENCES Produse(id),
    id_ingredient INT           NOT NULL REFERENCES Ingrediente(id),
    cantitate     DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (id_produs, id_ingredient)
);
GO

-- ============================================================
--  6. ANGAJATI
--  rol: 'admin' | 'chelner'
-- ============================================================
CREATE TABLE Angajati (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    nume        NVARCHAR(100) NOT NULL,
    prenume     NVARCHAR(100) NOT NULL,
    rol         NVARCHAR(20)  NOT NULL CHECK (rol IN ('admin','chelner')),
    username    NVARCHAR(100) NOT NULL UNIQUE,
    parola_hash NVARCHAR(256) NOT NULL
);
GO

-- ============================================================
--  7. VANZARI
-- ============================================================
CREATE TABLE Vanzari (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    id_angajat  INT           NOT NULL REFERENCES Angajati(id),
    data_ora    DATETIME      NOT NULL DEFAULT GETDATE(),
    total       DECIMAL(10,2) NOT NULL DEFAULT 0
);
GO

-- ============================================================
--  8. DETALII_VANZARI
-- ============================================================
CREATE TABLE Detalii_Vanzari (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    id_vanzare  INT           NOT NULL REFERENCES Vanzari(id),
    id_produs   INT           NOT NULL REFERENCES Produse(id),
    cantitate   INT           NOT NULL DEFAULT 1,
    pret_unitar DECIMAL(10,2) NOT NULL
);
GO

-- ============================================================
--  9. STOC_MANUAL — produse care nu se tasteaza
--     (hartie, servetele, manusi, betisoare, zahar etc.)
-- ============================================================
CREATE TABLE Stoc_Manual (
    id               INT IDENTITY(1,1) PRIMARY KEY,
    nume_produs      NVARCHAR(200) NOT NULL,
    unitate          NVARCHAR(50)  NOT NULL,
    cantitate        DECIMAL(10,2) NOT NULL DEFAULT 0,
    cantitate_minima DECIMAL(10,2) NOT NULL DEFAULT 0,
    data_actualizare DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
--  10. LOG_ACTIVITATE — cine a facut ce si cand
-- ============================================================
CREATE TABLE Log_Activitate (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    id_angajat  INT           NOT NULL REFERENCES Angajati(id),
    actiune     NVARCHAR(500) NOT NULL,
    data_ora    DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
--  STORED PROCEDURE: scadere automata stoc dupa vanzare
-- ============================================================
CREATE OR ALTER PROCEDURE sp_ScadeStocDupaVanzare
    @id_vanzare INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Pentru produse cu reteta (ingrediente / premix)
    UPDATE S
    SET S.cantitate_disponibila = S.cantitate_disponibila
        - (PI.cantitate * DV.cantitate)
    FROM Stocuri S
    INNER JOIN Produs_Ingrediente PI ON S.id_ingredient = PI.id_ingredient
    INNER JOIN Detalii_Vanzari DV   ON PI.id_produs     = DV.id_produs
    INNER JOIN Produse P            ON DV.id_produs      = P.id
    WHERE DV.id_vanzare = @id_vanzare
      AND P.tip_scadere IN ('ingrediente','premix');

    -- Pentru bauturi tari: 40 ml per portie din ingredientul principal
    UPDATE S
    SET S.cantitate_disponibila = S.cantitate_disponibila - (40 * DV.cantitate)
    FROM Stocuri S
    INNER JOIN Produs_Ingrediente PI ON S.id_ingredient = PI.id_ingredient
    INNER JOIN Detalii_Vanzari DV   ON PI.id_produs     = DV.id_produs
    INNER JOIN Produse P            ON DV.id_produs      = P.id
    WHERE DV.id_vanzare = @id_vanzare
      AND P.tip_scadere = 'portie';

    -- Pentru produse unitare (bucati)
    UPDATE S
    SET S.cantitate_disponibila = S.cantitate_disponibila - DV.cantitate
    FROM Stocuri S
    INNER JOIN Produs_Ingrediente PI ON S.id_ingredient = PI.id_ingredient
    INNER JOIN Detalii_Vanzari DV   ON PI.id_produs     = DV.id_produs
    INNER JOIN Produse P            ON DV.id_produs      = P.id
    WHERE DV.id_vanzare = @id_vanzare
      AND P.tip_scadere = 'bucata';
END;
GO

-- ============================================================
--  STORED PROCEDURE: produse cu stoc critic (sub minim)
-- ============================================================
CREATE OR ALTER PROCEDURE sp_StocCritic
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        I.nume            AS Ingredient,
        S.cantitate_disponibila AS Disponibil,
        S.cantitate_minima      AS Minim,
        I.unitate_masura        AS Unitate
    FROM Stocuri S
    INNER JOIN Ingrediente I ON S.id_ingredient = I.id
    WHERE S.cantitate_disponibila <= S.cantitate_minima
    ORDER BY S.cantitate_disponibila ASC;
END;
GO

-- ============================================================
--  SEED: date initiale — categorii
-- ============================================================
INSERT INTO Categorii (nume, tip) VALUES
    ('Bucatarie Europeana',  'european'),
    ('Bucatarie Japoneza',   'japonez'),
    ('Cocktailuri & Bar',    'bar'),
    ('Bauturi Unitare',      'bauturi'),
    ('Bauturi Spirtoase',    'bauturi'),
    ('Stoc Manual',          'manual');
GO

-- ============================================================
--  SEED: angajat admin implicit
--  parola: Admin1234 (SHA-256, de inlocuit in aplicatie)
-- ============================================================
INSERT INTO Angajati (nume, prenume, rol, username, parola_hash) VALUES
    ('Burdeniuc', 'Alex-Nicolae', 'admin', 'admin',
     '0f775e65d2e83ed532d4339d29a4bddf81d27f65c60e0dc8893068c04cfa0b65');
GO

-- ============================================================
--  SEED: stoc manual initial
-- ============================================================
INSERT INTO Stoc_Manual (nume_produs, unitate, cantitate, cantitate_minima) VALUES
    ('Hartie igienica',      'rola',  50,  10),
    ('Servetele de masa',    'buc',   500, 100),
    ('Manusi latex',         'buc',   200, 50),
    ('Betisoare pentru sushi','set',  300, 50),
    ('Zahar portionat',      'plic',  400, 100),
    ('Scobitori',            'buc',   1000,200),
    ('Pungi menaj',          'buc',   100, 20),
    ('Folie alimentara',     'rola',  5,   1),
    ('Detergent vase',       'l',     10,  2),
    ('Burete vase',          'buc',   20,  5);
GO

PRINT 'MojitoDB creat cu succes!';
GO


USE MojitoDB;

INSERT INTO Ingrediente (nume, unitate_masura) VALUES
('Piept de pui',     'g'),
('Cartofi',          'g'),
('Ulei floarea soarelui', 'ml'),
('Orez pentru sushi','g'),
('Somon proaspat',   'g'),
('Vodca',            'ml'),
('Premix Mojito',    'ml'),
('Dorna 0.3L',       'buc'),
('Cola 0.25L',       'buc'),
('Lamaie',           'g');
GO

INSERT INTO Stocuri (id_ingredient, cantitate_disponibila, cantitate_minima) VALUES
(1,  5000, 500),   -- Piept de pui: 5kg, minim 500g
(2,  8000, 1000),  -- Cartofi: 8kg, minim 1kg
(3,  3000, 500),   -- Ulei: 3L, minim 500ml
(4,  5000, 500),   -- Orez sushi: 5kg, minim 500g
(5,  3000, 300),   -- Somon: 3kg, minim 300g
(6,  5000, 400),   -- Vodca: 5L, minim 400ml
(7,  4000, 400),   -- Premix Mojito: 4L, minim 400ml
(8,  48,   6),     -- Dorna: 48 buc, minim 6
(9,  48,   6),     -- Cola: 48 buc, minim 6
(10, 2000, 200);   -- Lamaie: 2kg, minim 200g
GO

SELECT 
    I.nume            AS Ingredient,
    S.cantitate_disponibila AS Disponibil,
    S.cantitate_minima      AS Minim,
    I.unitate_masura        AS Unitate
FROM Stocuri S
INNER JOIN Ingrediente I ON S.id_ingredient = I.id
ORDER BY I.nume;
GO

USE MojitoDB;

-- Inserare produs test (Vodca 40ml portie)
INSERT INTO Produse (nume, id_categorie, pret, gramaj, tip_scadere) VALUES
('Vodca Absolut', 5, 45.00, '40ml', 'portie');

-- Inserare vanzare test
INSERT INTO Vanzari (id_angajat, total) VALUES (1, 45.00);

-- Inserare detaliu vanzare (1 portie vodca)
INSERT INTO Detalii_Vanzari (id_vanzare, id_produs, cantitate, pret_unitar)
VALUES (1, 1, 1, 45.00);
GO

EXEC sp_ScadeStocDupaVanzare @id_vanzare = 1;
GO

SELECT 
    I.nume        AS Ingredient,
    S.cantitate_disponibila AS Dupa_Vanzare,
    I.unitate_masura AS Unitate
FROM Stocuri S
INNER JOIN Ingrediente I ON S.id_ingredient = I.id
WHERE I.nume = 'Vodca';
GO

EXEC sp_StocCritic;
GO

USE MojitoDB;

-- Legam produsul Vodca Absolut (id=1) de ingredientul Vodca (id=6)
INSERT INTO Produs_Ingrediente (id_produs, id_ingredient, cantitate)
VALUES (1, 6, 40);  -- 40ml per portie
GO

-- Rulam din nou procedura
EXEC sp_ScadeStocDupaVanzare @id_vanzare = 1;
GO

-- Verificam stocul
SELECT 
    I.nume AS Ingredient,
    S.cantitate_disponibila AS Dupa_Vanzare,
    I.unitate_masura AS Unitate
FROM Stocuri S
INNER JOIN Ingrediente I ON S.id_ingredient = I.id
WHERE I.nume = 'Vodca';
GO

-- Simulam un stoc critic pentru test
UPDATE Stocuri SET cantitate_disponibila = 3 WHERE id_ingredient = 8; -- Dorna sub minim
UPDATE Stocuri SET cantitate_disponibila = 2 WHERE id_ingredient = 9; -- Cola sub minim
GO

EXEC sp_StocCritic;
GO

USE MojitoDB;

UPDATE Angajati 
SET parola_hash = '0f775e65d2e83ed532d4339d29a4bddf81d27f65c60e0dc8893068c04cfa0b65'
WHERE username = 'admin';

SELECT username, parola_hash FROM Angajati;
GO

USE MojitoDB;

UPDATE Angajati 
SET parola_hash = '60fe74406e7f353ed979f350f2fbb6a2e8690a5fa7d1b0c32983d1d8b3f95f67'
WHERE username = 'admin';
GO
USE MojitoDB;

INSERT INTO Produse (nume, id_categorie, pret, gramaj, tip_scadere) VALUES
('Supă de pui',         1, 45.00, '300ml', 'ingrediente'),
('Ciorbă de burtă',     1, 55.00, '300ml', 'ingrediente'),
('Cotlet de porc',      1, 89.00, '200g',  'ingrediente'),
('Piept de pui la grătar', 1, 79.00, '200g', 'ingrediente'),
('Cartofi prăjiți',     1, 35.00, '200g',  'ingrediente'),
('Salată de casă',      1, 40.00, '200g',  'ingrediente'),
('Paste Carbonara',     1, 75.00, '300g',  'ingrediente'),
('Pizza Margherita',    1, 85.00, '350g',  'ingrediente');
GO

USE MojitoDB;

INSERT INTO Produse (nume, id_categorie, pret, gramaj, tip_scadere) VALUES
('Philadelphia Roll',     2, 95.00,  '8 buc', 'ingrediente'),
('California Roll',       2, 85.00,  '8 buc', 'ingrediente'),
('Dragon Roll',           2, 110.00, '8 buc', 'ingrediente'),
('Spicy Tuna Roll',       2, 100.00, '8 buc', 'ingrediente'),
('Rainbow Roll',          2, 120.00, '8 buc', 'ingrediente'),
('Salmon Nigiri',         2, 65.00,  '2 buc', 'ingrediente'),
('Tuna Nigiri',           2, 70.00,  '2 buc', 'ingrediente'),
('Ebi Gunkan',            2, 60.00,  '2 buc', 'ingrediente'),
('Salmon Poke Bowl',      2, 115.00, '350g',  'ingrediente'),
('Tuna Poke Bowl',        2, 120.00, '350g',  'ingrediente');
GO

USE MojitoDB;

-- Stergere produse japoneze vechi
DELETE FROM Produs_Ingrediente WHERE id_produs IN (SELECT id FROM Produse WHERE id_categorie = 2);
DELETE FROM Produse WHERE id_categorie = 2;

-- Stergere ingrediente vechi de test
DELETE FROM Stocuri WHERE id_ingredient > 10;
DELETE FROM Ingrediente WHERE id > 10;

-- Ingrediente complete
INSERT INTO Ingrediente (nume, unitate_masura) VALUES
('Orez sushi',          'g'),   -- 11
('Nori',                'g'),   -- 12
('Crema de branza',     'g'),   -- 13
('Mango',               'g'),   -- 14
('Creveti',             'g'),   -- 15
('Castravete',          'g'),   -- 16
('Somon',               'g'),   -- 17
('Sos truffle aioli',   'g'),   -- 18
('Icre rosii',          'g'),   -- 19
('Ghimbir',             'g'),   -- 20
('Wasabi',              'g'),   -- 21
('Sos de soia',         'g'),   -- 22
('Icre masago',         'g'),   -- 23
('Avocado',             'g'),   -- 24
('Sos unagi',           'g'),   -- 25
('Sos picant',          'g'),   -- 26
('Tipar',               'g'),   -- 27
('Ton',                 'g'),   -- 28
('Seminte de susan',    'g'),   -- 29
('Omleta',              'g'),   -- 30
('Creveti tempura',     'g'),   -- 31
('Creveti pane',        'g'),   -- 32
('Creveti fierti',      'g'),   -- 33
('Somon flambat',       'g'),   -- 34
('Somon prajit',        'g'),   -- 35
('Foi de soia mamenori','g'),   -- 36
('Alge chuka',          'g'),   -- 37
('Salata iceberg',      'g'),   -- 38
('Ardei dulce',         'g'),   -- 39
('Salsa mango rosii',   'g'),   -- 40
('Busuioc',             'g'),   -- 41
('Panko',               'g'),   -- 42
('Icre tobiko',         'g'),   -- 43
('Tartar de tipar',     'g'),   -- 44
('Tartar de somon',     'g'),   -- 45
('Tartar de creveti',   'g'),   -- 46
('Takuan',              'g'),   -- 47
('Fulgi de ton',        'g'),   -- 48
('Praz prajit',         'g'),   -- 49
('Para kimchi',         'g'),   -- 50
('Edamame',             'g'),   -- 51
('Sos sweet chili',     'g'),   -- 52
('Rosii cherry',        'g'),   -- 53
('Porumb',              'g'),   -- 54
('Ridiche',             'g'),   -- 55
('Sos ponzu',           'g'),   -- 56
('Sos de nuci',         'g');   -- 57
GO
INSERT INTO Stocuri (id_ingredient, cantitate_disponibila, cantitate_minima)
SELECT id, 2000, 200 FROM Ingrediente WHERE id BETWEEN 11 AND 57;
GO

INSERT INTO Produse (nume, id_categorie, pret, gramaj, tip_scadere) VALUES
('Kitsune',                    2, 205.00, '280g', 'ingrediente'),  -- 1
('Alaska',                     2, 165.00, '280g', 'ingrediente'),  -- 2
('Yin & Yang',                 2, 175.00, '280g', 'ingrediente'),  -- 3
('Philadelphia Salmon',        2, 175.00, '280g', 'ingrediente'),  -- 4
('Philadelphia Shrimp',        2, 175.00, '280g', 'ingrediente'),  -- 5
('Philadelphia Eel',           2, 190.00, '280g', 'ingrediente'),  -- 6
('Philadelphia Tuna',          2, 190.00, '280g', 'ingrediente'),  -- 7
('Philly Roll',                2, 195.00, '280g', 'ingrediente'),  -- 8
('Canada',                     2, 190.00, '280g', 'ingrediente'),  -- 9
('Mojito Roll',                2, 255.00, '280g', 'ingrediente'),  -- 10
('Vegan',                      2, 105.00, '280g', 'ingrediente'),  -- 11
('Totoro',                     2, 200.00, '280g', 'ingrediente'),  -- 12
('Kyoto',                      2, 190.00, '280g', 'ingrediente'),  -- 13
('Yuki',                       2, 180.00, '280g', 'ingrediente'),  -- 14
('Ebi Tempura',                2, 175.00, '280g', 'ingrediente'),  -- 15
('Basilico Salmon Tempura',    2, 180.00, '280g', 'ingrediente'),  -- 16
('Salmon Tempura',             2, 175.00, '280g', 'ingrediente'),  -- 17
('Shiro Tempura',              2, 175.00, '280g', 'ingrediente'),  -- 18
('Umami Tempura',              2, 169.00, '280g', 'ingrediente'),  -- 19
('Nigiri Salmon',              2, 55.00,  '40g',  'ingrediente'),  -- 20
('Nigiri Seared Salmon',       2, 55.00,  '40g',  'ingrediente'),  -- 21
('Nigiri Tuna',                2, 50.00,  '40g',  'ingrediente'),  -- 22
('Nigiri Seared Tuna',         2, 50.00,  '40g',  'ingrediente'),  -- 23
('Nigiri Shrimp',              2, 50.00,  '40g',  'ingrediente'),  -- 24
('Nigiri Eel',                 2, 55.00,  '40g',  'ingrediente'),  -- 25
('Nigiri Seared Eel',          2, 55.00,  '40g',  'ingrediente'),  -- 26
('Gunkan Salmon',              2, 60.00,  '35g',  'ingrediente'),  -- 27
('Gunkan Red Caviar',          2, 65.00,  '35g',  'ingrediente'),  -- 28
('Gunkan Shrimp',              2, 55.00,  '35g',  'ingrediente'),  -- 29
('Gunkan Eel',                 2, 50.00,  '35g',  'ingrediente'),  -- 30
('Gunkan Tobiko',              2, 45.00,  '35g',  'ingrediente'),  -- 31
('Gunkan Chuka',               2, 45.00,  '35g',  'ingrediente'),  -- 32
('Crunch Poke',                2, 169.00, '350g', 'ingrediente'),  -- 33
('Tempura Shrimp Poke',        2, 169.00, '350g', 'ingrediente'),  -- 34
('Malibu Poke',                2, 169.00, '350g', 'ingrediente'),  -- 35
('Philly Poke',                2, 169.00, '350g', 'ingrediente'),  -- 36
('Fish Trio Poke',             2, 285.00, '350g', 'ingrediente');  -- 37
GO

SELECT id, nume FROM Produse WHERE id_categorie = 2 ORDER BY id;
GO
USE MojitoDB;

-- Kitsune (20): orez,nori,crema branza,mango,creveti,castravete,somon,sos truffle aioli,icre rosii,ghimbir,wasabi
INSERT INTO Produs_Ingrediente VALUES
(20,11,100),(20,12,5),(20,13,40),(20,14,20),(20,15,50),(20,16,20),(20,17,60),(20,18,15),(20,19,10),(20,20,10),(20,21,5);

-- Alaska (21): orez,nori,crema branza,mango,icre masago,avocado,creveti fierti,castravete,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(21,11,100),(21,12,5),(21,13,40),(21,14,20),(21,23,10),(21,24,30),(21,33,50),(21,16,20),(21,20,10),(21,21,5),(21,22,15);

-- Yin & Yang (22): orez,nori,crema branza,mango,icre masago,castravete,creveti fierti,somon,sos unagi,sos picant,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(22,11,100),(22,12,5),(22,13,40),(22,14,20),(22,23,10),(22,16,20),(22,33,50),(22,17,40),(22,25,15),(22,26,10),(22,20,10),(22,21,5),(22,22,15);

-- Philadelphia Salmon (23): orez,nori,crema branza,avocado,somon,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(23,11,100),(23,12,5),(23,13,40),(23,24,30),(23,17,60),(23,20,10),(23,21,5),(23,22,15);

-- Philadelphia Shrimp (24): orez,nori,crema branza,avocado,creveti,sos unagi,sos picant,icre tobiko,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(24,11,100),(24,12,5),(24,13,40),(24,24,30),(24,15,50),(24,25,15),(24,26,10),(24,43,10),(24,20,10),(24,21,5),(24,22,15);

-- Philadelphia Eel (25): orez,nori,crema branza,avocado,tipar,sos unagi,seminte susan,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(25,11,100),(25,12,5),(25,13,40),(25,24,30),(25,27,60),(25,25,15),(25,29,5),(25,20,10),(25,21,5),(25,22,15);

-- Philadelphia Tuna (26): orez,nori,crema branza,avocado,ton,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(26,11,100),(26,12,5),(26,13,40),(26,24,30),(26,28,60),(26,20,10),(26,21,5),(26,22,15);

-- Philly Roll (27): orez,nori,crema branza,tipar,castravete,somon,sos unagi,seminte susan,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(27,11,100),(27,12,5),(27,13,40),(27,27,50),(27,16,20),(27,17,50),(27,25,15),(27,29,5),(27,20,10),(27,21,5),(27,22,15);

-- Canada (28): orez,nori,crema branza,avocado,omleta,tipar,sos unagi,seminte susan,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(28,11,100),(28,12,5),(28,13,40),(28,24,30),(28,30,30),(28,27,50),(28,25,15),(28,29,5),(28,20,10),(28,21,5),(28,22,15);

-- Mojito Roll (29): orez,nori,crema branza,castravete,creveti tempura,somon,avocado,sos picant,sos unagi,icre rosii,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(29,11,100),(29,12,5),(29,13,40),(29,16,20),(29,31,50),(29,17,50),(29,24,30),(29,26,10),(29,25,15),(29,19,10),(29,20,10),(29,21,5),(29,22,15);

-- Vegan (30): orez,nori,ardei dulce,castravete,avocado,salata iceberg,alge chuka,salsa mango rosii,seminte susan,sos unagi,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(30,11,100),(30,12,5),(30,39,30),(30,16,20),(30,24,30),(30,38,20),(30,37,20),(30,40,20),(30,29,5),(30,25,15),(30,20,10),(30,21,5),(30,22,15);

-- Totoro (31): orez,nori,crema branza,creveti pane,avocado,somon flambat,sos picant,icre tobiko,sos unagi,seminte susan,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(31,11,100),(31,12,5),(31,13,40),(31,32,50),(31,24,30),(31,34,50),(31,26,10),(31,43,10),(31,25,15),(31,29,5),(31,20,10),(31,21,5),(31,22,15);

-- Kyoto (32): orez,nori,crema branza,creveti pane,castravete,somon,sos picant,sos unagi,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(32,11,100),(32,12,5),(32,13,40),(32,32,50),(32,16,20),(32,17,50),(32,26,10),(32,25,15),(32,20,10),(32,21,5),(32,22,15);

-- Yuki (33): foi soia,crema branza,ardei dulce,ton,somon,avocado,salata iceberg,castravete,alge chuka,sos nuci,icre tobiko,sos unagi,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(33,36,10),(33,13,40),(33,39,30),(33,28,40),(33,17,40),(33,24,30),(33,38,20),(33,16,20),(33,37,20),(33,57,15),(33,43,10),(33,25,15),(33,20,10),(33,21,5),(33,22,15);

-- Ebi Tempura (34): orez,nori,crema branza,creveti fierti,icre tobiko,avocado,sos unagi,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(34,11,100),(34,12,5),(34,13,40),(34,33,50),(34,43,10),(34,24,30),(34,25,15),(34,20,10),(34,21,5),(34,22,15);

-- Basilico Salmon Tempura (35): orez,nori,crema branza,somon prajit,castravete,busuioc,panko,sos picant,sos unagi,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(35,11,100),(35,12,5),(35,13,40),(35,35,60),(35,16,20),(35,41,10),(35,42,15),(35,26,10),(35,25,15),(35,20,10),(35,21,5),(35,22,15);

-- Salmon Tempura (36): orez,nori,crema branza,somon,icre tobiko,avocado,sos unagi,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(36,11,100),(36,12,5),(36,13,40),(36,17,60),(36,43,10),(36,24,30),(36,25,15),(36,20,10),(36,21,5),(36,22,15);

-- Shiro Tempura (37): orez,nori,crema branza,creveti tempura,castravete,avocado,sos truffle aioli,sos picant,icre tobiko,sos unagi,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(37,11,100),(37,12,5),(37,13,40),(37,31,50),(37,16,20),(37,24,30),(37,18,15),(37,26,10),(37,43,10),(37,25,15),(37,20,10),(37,21,5),(37,22,15);

-- Umami Tempura (38): nori,crema branza,somon,castravete,avocado,tartar tipar,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(38,12,5),(38,13,40),(38,17,60),(38,16,20),(38,24,30),(38,44,40),(38,20,10),(38,21,5),(38,22,15);

-- Nigiri Salmon (39): orez,somon,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(39,11,25),(39,17,20),(39,20,5),(39,21,3),(39,22,8);

-- Nigiri Seared Salmon (40): orez,somon,sos soia,sos truffle aioli,icre rosii,ghimbir,wasabi
INSERT INTO Produs_Ingrediente VALUES
(40,11,25),(40,17,20),(40,22,8),(40,18,10),(40,19,5),(40,20,5),(40,21,3);

-- Nigiri Tuna (41): orez,ton,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(41,11,25),(41,28,20),(41,20,5),(41,21,3),(41,22,8);

-- Nigiri Seared Tuna (42): orez,ton,sos soia,sos truffle aioli,icre rosii,ghimbir,wasabi
INSERT INTO Produs_Ingrediente VALUES
(42,11,25),(42,28,20),(42,22,8),(42,18,10),(42,19,5),(42,20,5),(42,21,3);

-- Nigiri Shrimp (43): orez,creveti fierti,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(43,11,25),(43,33,20),(43,20,5),(43,21,3),(43,22,8);

-- Nigiri Eel (44): nori,orez,tipar,sos unagi,icre tobiko,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(44,12,3),(44,11,25),(44,27,20),(44,25,10),(44,43,5),(44,20,5),(44,21,3),(44,22,8);

-- Nigiri Seared Eel (45): orez,tipar,sos unagi,icre tobiko,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(45,11,25),(45,27,20),(45,25,10),(45,43,5),(45,20,5),(45,21,3),(45,22,8);

-- Gunkan Salmon (46): nori,orez,tartar somon,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(46,12,3),(46,11,20),(46,45,25),(46,20,5),(46,21,3),(46,22,8);

-- Gunkan Red Caviar (47): nori,orez,icre rosii,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(47,12,3),(47,11,20),(47,19,15),(47,20,5),(47,21,3),(47,22,8);

-- Gunkan Shrimp (48): nori,orez,tartar creveti,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(48,12,3),(48,11,20),(48,46,25),(48,20,5),(48,21,3),(48,22,8);

-- Gunkan Eel (49): nori,orez,tartar tipar,sos unagi,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(49,12,3),(49,11,20),(49,44,25),(49,25,10),(49,20,5),(49,21,3),(49,22,8);

-- Gunkan Tobiko (50): nori,orez,icre tobiko,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(50,12,3),(50,11,20),(50,43,15),(50,20,5),(50,21,3),(50,22,8);

-- Gunkan Chuka (51): nori,orez,sos nuci,alge chuka,ghimbir,wasabi,sos soia
INSERT INTO Produs_Ingrediente VALUES
(51,12,3),(51,11,20),(51,57,10),(51,37,20),(51,20,5),(51,21,3),(51,22,8);

-- Crunch Poke (52): orez,tipar,castravete,takuan,avocado,fulgi ton,sos unagi,seminte susan,praz prajit,sos soia
INSERT INTO Produs_Ingrediente VALUES
(52,11,150),(52,27,60),(52,16,30),(52,47,20),(52,24,40),(52,48,10),(52,25,20),(52,29,5),(52,49,10),(52,22,20);

-- Tempura Shrimp Poke (53): orez,mango,castravete,para kimchi,edamame,creveti tempura,sos sweet chili,seminte susan,rosii cherry,fulgi ton,sos soia
INSERT INTO Produs_Ingrediente VALUES
(53,11,150),(53,14,30),(53,16,30),(53,50,20),(53,51,30),(53,31,60),(53,52,20),(53,29,5),(53,53,20),(53,48,10),(53,22,20);

-- Malibu Poke (54): orez,mango,alge chuka,rosii cherry,porumb,ridiche,avocado,tartar creveti,sos unagi,seminte susan,sos soia
INSERT INTO Produs_Ingrediente VALUES
(54,11,150),(54,14,30),(54,37,20),(54,53,20),(54,54,20),(54,55,15),(54,24,40),(54,46,50),(54,25,20),(54,29,5),(54,22,20);

-- Philly Poke (55): orez,mango,edamame,rosii cherry,castravete,avocado,somon,sos ponzu,sos unagi,icre tobiko,sos soia
INSERT INTO Produs_Ingrediente VALUES
(55,11,150),(55,14,30),(55,51,30),(55,53,20),(55,16,30),(55,24,40),(55,17,60),(55,56,15),(55,25,20),(55,43,10),(55,22,20);

-- Fish Trio Poke (56): orez,mango,rosii cherry,avocado,alge chuka,somon,ton,creveti,avocado
INSERT INTO Produs_Ingrediente VALUES
(56,11,150),(56,14,30),(56,53,20),(56,24,50),(56,37,20),(56,17,50),(56,28,50),(56,15,50),(56,24,40);
GO
-- Fish Trio Poke (56): orez,mango,rosii cherry,avocado,alge chuka,somon,ton,creveti
INSERT INTO Produs_Ingrediente VALUES
(56,11,150),(56,14,30),(56,53,20),(56,24,90),(56,37,20),(56,17,50),(56,28,50),(56,15,50);
GO

USE MojitoDB;

-- Stergem datele de test in ordinea corecta
DELETE FROM Detalii_Vanzari WHERE id_produs IN (SELECT id FROM Produse WHERE id_categorie = 1);
DELETE FROM Vanzari WHERE id NOT IN (SELECT DISTINCT id_vanzare FROM Detalii_Vanzari);
DELETE FROM Produs_Ingrediente WHERE id_produs IN (SELECT id FROM Produse WHERE id_categorie = 1);
DELETE FROM Produse WHERE id_categorie = 1;
GO
USE MojitoDB;

-- ============================================================
-- Stergere produse europene vechi
-- ============================================================
DELETE FROM Produs_Ingrediente WHERE id_produs IN (SELECT id FROM Produse WHERE id_categorie = 1);
DELETE FROM Produse WHERE id_categorie = 1;

-- ============================================================
-- PRODUSE EUROPENE cu preturi realiste (MDL)
-- ============================================================
INSERT INTO Produse (nume, id_categorie, pret, gramaj, tip_scadere) VALUES
-- MIC DEJUN (100-145 MDL)
('Scrumble cu creveti si orez prajit',                1, 135.00, '350g', 'ingrediente'),
('Terci de ovaz cu mango si cocos',                   1, 100.00, '430g', 'ingrediente'),
('Terci de ovaz cu fructe uscate si miere',           1, 100.00, '430g', 'ingrediente'),
('Syrniki cu mango si sos vanilie',                   1, 120.00, '290g', 'ingrediente'),
('Syrniki cu smantana si gem de caise',               1, 110.00, '280g', 'ingrediente'),
('Shakshuka cu ou pocheat',                           1, 130.00, '350g', 'ingrediente'),
('Mic dejun englezesc',                               1, 145.00, '550g', 'ingrediente'),
('Omleta cu creveti si guacamole',                    1, 140.00, '380g', 'ingrediente'),
('Oua pocheat cu bacon',                              1, 130.00, '305g', 'ingrediente'),
('Oua pocheat cu somon si icre rosii',                1, 145.00, '340g', 'ingrediente'),
-- GUSTARI (140-700 MDL)
('Guacamole cu nachos',                               1, 145.00, '180g', 'ingrediente'),
('Fritto misto',                                      1, 280.00, '700g', 'ingrediente'),
('Tartare de somon cu guacamole si briosa',           1, 260.00, '250g', 'ingrediente'),
('Tartare de vita cu icre rosii si lipie de cartofi', 1, 320.00, '220g', 'ingrediente'),
('Set de gustari asiatice',                           1, 420.00, '900g', 'ingrediente'),
('Set de gustari',                                    1, 380.00, '710g', 'ingrediente'),
-- FINGER FOOD (140-280 MDL)
('Crunch Set',                                        1, 200.00, '680g', 'ingrediente'),
('Aripioare de pui BBQ cu cartofi prajiti',           1, 175.00, '550g', 'ingrediente'),
('Popcorn de pui cu cartofi prajiti',                 1, 150.00, '420g', 'ingrediente'),
('Creveti pane cu sos chili-mayo si cartofi',         1, 165.00, '350g', 'ingrediente'),
('Smash burger cu vita',                              1, 210.00, '580g', 'ingrediente'),
('Burger Cezar cu snitel de pui',                     1, 195.00, '480g', 'ingrediente'),
-- GARNITURI (55-120 MDL)
('Broccoli grill cu sos miere-mustar',                1,  85.00, '240g', 'ingrediente'),
('Conopida cu sos truffle',                           1,  95.00, '340g', 'ingrediente'),
('Orez jasmin pe lapte de cocos cu sos unagi',        1,  65.00, '215g', 'ingrediente'),
('Batata fries cu parmezan',                          1,  75.00, '186g', 'ingrediente'),
-- PESTE (220-340 MDL)
('File de dorada cu varza de Bruxelles si spanac',    1, 245.00, '320g', 'ingrediente'),
('Steak de somon in sos cremos cu icre rosii',        1, 280.00, '270g', 'ingrediente'),
('Steak de ton cu legume sotate si sos romesco',      1, 310.00, '385g', 'ingrediente'),
-- CARNE (140-340 MDL)
('Pui la cuptor cu cartofi in sos cremos',            1, 185.00, '540g', 'ingrediente'),
('Piept de pui cu legume sotate si sos cremos',       1, 160.00, '340g', 'ingrediente'),
('Medalion de vita cu piure si sos demi-glace',       1, 320.00, '310g', 'ingrediente'),
('Pepper steak cu cartofi zdrobiti si sos de piper',  1, 340.00, '465g', 'ingrediente'),
('Coaste de porc inabsite cu cartofi prajiti',        1, 195.00, '420g', 'ingrediente'),
('Muschi de porc la cuptor cu cartofi si ciuperci',   1, 175.00, '480g', 'ingrediente');
GO

-- ============================================================
-- INGREDIENTE noi pentru bucataria europeana
-- ============================================================
INSERT INTO Ingrediente (nume, unitate_masura) VALUES
('Oua de gaina',                'g'),   -- 58
('Smantana',                    'g'),   -- 59
('Lapte',                       'g'),   -- 60
('Unt',                         'g'),   -- 61
('Faina',                       'g'),   -- 62
('Zahar',                       'g'),   -- 63
('Sare',                        'g'),   -- 64
('Piper negru',                 'g'),   -- 65
('Ulei vegetal',                'g'),   -- 66
('Ulei de masline',             'g'),   -- 67
('Frisca',                      'g'),   -- 68
('Vin alb',                     'g'),   -- 69
('Usturoi',                     'g'),   -- 70
('Ceapa',                       'g'),   -- 71
('Fulgi de ovaz',               'g'),   -- 72
('Mango conservat',             'g'),   -- 73
('Fistic maruntit',             'g'),   -- 74
('Cocos maruntit',              'g'),   -- 75
('Merisoare uscate',            'g'),   -- 76
('Curmale',                     'g'),   -- 77
('Smochine',                    'g'),   -- 78
('Miere',                       'g'),   -- 79
('Syrniki 3x50g',               'g'),   -- 80
('Gem de caise',                'g'),   -- 81
('Capsune',                     'g'),   -- 82
('Zahar pudra',                 'g'),   -- 83
('Sos shakshuka',               'g'),   -- 84
('Vinete',                      'g'),   -- 85
('Branza de capra',             'g'),   -- 86
('Coriandru',                   'g'),   -- 87
('Busuioc proaspat',            'g'),   -- 88
('Patrunjel',                   'g'),   -- 89
('Paine',                       'g'),   -- 90
('Carnati de pui',              'g'),   -- 91
('Ciuperci champignon',         'g'),   -- 92
('Branza halumi',               'g'),   -- 93
('Bacon',                       'g'),   -- 94
('Spanac',                      'g'),   -- 95
('Fasole rosie conservata',     'g'),   -- 96
('Branza olandeza',             'g'),   -- 97
('Sos guacamole',               'g'),   -- 98
('Salsa de rosii',              'g'),   -- 99
('Paine de grau',               'g'),   -- 100
('Branza de capra moale',       'g'),   -- 101
('Mix de salata',               'g'),   -- 102
('Sos olandez',                 'g'),   -- 103
('Nachos',                      'g'),   -- 104
('Ceapa rosie',                 'g'),   -- 105
('Lime',                        'g'),   -- 106
('Piper chili',                 'g'),   -- 107
('Creveti 16/20',               'g'),   -- 108
('Cartofi prajiti',             'g'),   -- 109
('Sos chili-mayo',              'g'),   -- 110
('Lamaie',                      'g'),   -- 111
('Somon curatat',               'g'),   -- 112
('Paine briosa',                'g'),   -- 113
('Icre rosii',                  'g'),   -- 114
('Sos kimchi',                  'g'),   -- 115
('Vita tocata cotlet',          'g'),   -- 116
('Mustar american',             'g'),   -- 117
('Sos BBQ',                     'g'),   -- 118
('Branza cheddar',              'g'),   -- 119
('Castraveti murati',           'g'),   -- 120
('Pui aripioare marinate',      'g'),   -- 121
('Pui popcorn',                 'g'),   -- 122
('Creveti pane',                'g'),   -- 123
('Bulochka pentru burger',      'g'),   -- 124
('Pui file panat',              'g'),   -- 125
('Broccoli',                    'g'),   -- 126
('Sos truffle',                 'g'),   -- 127
('Ulei truffle',                'g'),   -- 128
('Orez jasmin',                 'g'),   -- 129
('Lapte de cocos',              'g'),   -- 130
('Batata fries',                'g'),   -- 131
('Parmezan',                    'g'),   -- 132
('File de dorada',              'g'),   -- 133
('Varza de Bruxelles',          'g'),   -- 134
('Sos beurre blanc',            'g'),   -- 135
('Steak de somon',              'g'),   -- 136
('Ton steak',                   'g'),   -- 137
('Fasole kenyiana',             'g'),   -- 138
('Sos romesco',                 'g'),   -- 139
('Pui intreg',                  'g'),   -- 140
('Cartofi',                     'g'),   -- 141
('Pui file',                    'g'),   -- 142
('Conopida',                    'g'),   -- 143
('Porumb bebi',                 'g'),   -- 144
('Vita vrezka medalion',        'g'),   -- 145
('Piure de cartofi',            'g'),   -- 146
('Sos demi-glace',              'g'),   -- 147
('Vita vrezka steak',           'g'),   -- 148
('Sos de piper',                'g'),   -- 149
('Coaste de porc',              'g'),   -- 150
('Mustar zernos',               'g'),   -- 151
('Muschi de porc',              'g'),   -- 152
('Maioneza',                    'g'),   -- 153
('Calamar',                     'g'),   -- 154
('Sos unagi european',          'g');   -- 155
GO

-- Stocuri initiale
INSERT INTO Stocuri (id_ingredient, cantitate_disponibila, cantitate_minima)
SELECT id, 3000, 300 FROM Ingrediente WHERE id BETWEEN 58 AND 155;
GO

-- Verificare ID-uri produse europene
SELECT id, nume FROM Produse WHERE id_categorie = 1 ORDER BY id;
GO

USE MojitoDB;

-- ============================================================
-- RETETE BUCATARIE EUROPEANA (Produs_Ingrediente)
-- ID produse: 92-126
-- ============================================================

-- 92: Scrumble cu creveti si orez prajit
INSERT INTO Produs_Ingrediente VALUES
(92,58,100),(92,66,15),(92,59,100),(92,68,15),(92,97,20),(92,61,10),(92,64,2),(92,108,55),(92,67,10),(92,155,5),(92,89,2);

-- 93: Terci de ovaz cu mango si cocos
INSERT INTO Produs_Ingrediente VALUES
(93,72,70),(93,60,150),(93,63,5),(93,61,10),(93,64,2),(93,73,50),(93,74,5),(93,75,10);

-- 94: Terci de ovaz cu fructe uscate si miere
INSERT INTO Produs_Ingrediente VALUES
(94,72,70),(94,60,150),(94,63,5),(94,61,10),(94,64,2),(94,76,30),(94,77,30),(94,78,30),(94,79,40),(94,74,5);

-- 95: Syrniki cu mango si sos vanilie
INSERT INTO Produs_Ingrediente VALUES
(95,80,150),(95,67,5),(95,73,25),(95,82,20),(95,74,5),(95,85,20);

-- 96: Syrniki cu smantana si gem de caise
INSERT INTO Produs_Ingrediente VALUES
(96,80,150),(96,67,5),(96,59,50),(96,81,50),(96,83,3),(96,85,20),(96,74,5);

-- 97: Shakshuka cu ou pocheat
INSERT INTO Produs_Ingrediente VALUES
(97,84,180),(97,58,100),(97,89,2),(97,64,2),(97,65,1),(97,85,80),(97,62,10),(97,86,5),(97,88,2),(97,87,2),(97,90,60);

-- 98: Mic dejun englezesc
INSERT INTO Produs_Ingrediente VALUES
(98,58,100),(98,91,150),(98,92,50),(98,96,60),(98,93,40),(98,94,60),(98,64,2),(98,65,1),(98,67,15),(98,95,25),(98,96,100),(98,87,2),(98,88,2),(98,89,2);

-- 99: Omleta cu creveti si guacamole
INSERT INTO Produs_Ingrediente VALUES
(99,58,90),(99,60,25),(99,64,2),(99,65,1),(99,97,30),(99,108,80),(99,102,30),(99,69,20),(99,67,15),(99,98,45),(99,99,45);

-- 100: Oua pocheat cu bacon
INSERT INTO Produs_Ingrediente VALUES
(100,100,60),(100,101,25),(100,102,10),(100,112,60),(100,94,40),(100,58,100),(100,103,25),(100,89,5);

-- 101: Oua pocheat cu somon si icre rosii
INSERT INTO Produs_Ingrediente VALUES
(101,100,60),(101,101,25),(101,102,10),(101,112,60),(101,112,50),(101,103,25),(101,114,10),(101,58,100);

-- 102: Guacamole cu nachos
INSERT INTO Produs_Ingrediente VALUES
(102,98,100),(102,105,5),(102,106,3),(102,87,2),(102,65,2),(102,107,3),(102,67,10),(102,104,40);

-- 103: Fritto misto
INSERT INTO Produs_Ingrediente VALUES
(103,154,85),(103,154,80),(103,126,40),(103,108,80),(103,109,120),(103,62,20),(103,64,2),(103,65,1),(103,110,50),(103,111,25);

-- 104: Tartare de somon cu guacamole si briosa
INSERT INTO Produs_Ingrediente VALUES
(104,112,80),(104,98,80),(104,67,5),(104,68,5),(104,113,50),(104,64,2),(104,114,5);

-- 105: Tartare de vita cu icre rosii si lipie de cartofi
INSERT INTO Produs_Ingrediente VALUES
(105,115,3),(105,64,2),(105,65,1),(105,68,5),(105,114,8),(105,116,140);

-- 106: Set de gustari asiatice
INSERT INTO Produs_Ingrediente VALUES
(106,109,120),(106,110,50),(106,154,80),(106,108,80),(106,111,25);

-- 107: Set de gustari
INSERT INTO Produs_Ingrediente VALUES
(107,116,95),(107,125,90),(107,123,95),(107,109,120),(107,110,50),(107,111,25);

-- 108: Crunch Set
INSERT INTO Produs_Ingrediente VALUES
(108,109,120),(108,97,130),(108,123,130),(108,110,50),(108,110,50);

-- 109: Aripioare de pui BBQ cu cartofi prajiti
INSERT INTO Produs_Ingrediente VALUES
(109,121,310),(109,118,60),(109,109,120),(109,64,2),(109,110,50),(109,115,5),(109,128,2);

-- 110: Popcorn de pui cu cartofi prajiti
INSERT INTO Produs_Ingrediente VALUES
(110,122,180),(110,109,120),(110,110,50);

-- 111: Creveti pane cu sos chili-mayo si cartofi
INSERT INTO Produs_Ingrediente VALUES
(111,123,130),(111,110,50),(111,109,120),(111,64,2);

-- 112: Smash burger cu vita
INSERT INTO Produs_Ingrediente VALUES
(112,124,60),(112,116,180),(112,117,20),(112,118,30),(112,94,60),(112,119,25),(112,71,10),(112,120,15),(112,109,120),(112,110,50);

-- 113: Burger Cezar cu snitel de pui
INSERT INTO Produs_Ingrediente VALUES
(113,124,60),(113,117,10),(113,125,95),(113,119,15),(113,102,25),(113,132,5),(113,109,120),(113,110,50);

-- 114: Broccoli grill cu sos miere-mustar
INSERT INTO Produs_Ingrediente VALUES
(114,126,200),(114,67,10),(114,64,2),(114,65,1),(114,79,15),(114,117,10),(114,128,2);

-- 115: Conopida cu sos truffle
INSERT INTO Produs_Ingrediente VALUES
(115,143,260),(115,67,5),(115,64,2),(115,65,1),(115,127,70),(115,128,2);

-- 116: Orez jasmin pe lapte de cocos cu sos unagi
INSERT INTO Produs_Ingrediente VALUES
(116,129,150),(116,130,25),(116,64,2),(116,155,10);

-- 117: Batata fries cu parmezan
INSERT INTO Produs_Ingrediente VALUES
(117,131,130),(117,64,2),(117,132,6),(117,110,50);

-- 118: File de dorada cu varza de Bruxelles si spanac
INSERT INTO Produs_Ingrediente VALUES
(118,133,140),(118,64,2),(118,65,1),(118,61,10),(118,134,50),(118,95,15),(118,135,80);

-- 119: Steak de somon in sos cremos cu icre rosii
INSERT INTO Produs_Ingrediente VALUES
(119,136,145),(119,114,8),(119,67,10),(119,64,2),(119,65,1),(119,68,68),(119,146,30);

-- 120: Steak de ton cu legume sotate si sos romesco
INSERT INTO Produs_Ingrediente VALUES
(120,137,165),(120,67,10),(120,64,2),(120,65,1),(120,134,75),(120,138,35),(120,139,85),(120,61,5),(120,95,15);

-- 121: Pui la cuptor cu cartofi in sos cremos
INSERT INTO Produs_Ingrediente VALUES
(121,140,265),(121,141,120),(121,67,10),(121,71,14),(121,92,30),(121,68,80),(121,64,2),(121,65,1),(121,95,15),(121,155,15);

-- 122: Piept de pui cu legume sotate si sos cremos
INSERT INTO Produs_Ingrediente VALUES
(122,142,140),(122,126,43),(122,143,43),(122,134,43),(122,144,43),(122,61,5),(122,67,10),(122,64,2),(122,65,1),(122,132,4);

-- 123: Medalion de vita cu piure si sos demi-glace
INSERT INTO Produs_Ingrediente VALUES
(123,146,110),(123,60,10),(123,61,10),(123,64,1),(123,145,125),(123,67,10),(123,65,2),(123,65,1),(123,147,40),(123,95,15);

-- 124: Pepper steak cu cartofi zdrobiti si sos de piper
INSERT INTO Produs_Ingrediente VALUES
(124,148,210),(124,64,3),(124,65,1),(124,67,10),(124,61,10),(124,149,68),(124,141,155),(124,95,15);

-- 125: Coaste de porc inabsite cu cartofi prajiti
INSERT INTO Produs_Ingrediente VALUES
(125,150,270),(125,155,20),(125,109,120),(125,64,2),(125,117,10),(125,151,10),(125,115,10);

-- 126: Muschi de porc la cuptor cu cartofi si ciuperci
INSERT INTO Produs_Ingrediente VALUES
(126,71,17),(126,141,180),(126,92,25),(126,152,140),(126,67,5),(126,64,2),(126,65,1),(126,70,5),(126,153,50),(126,97,30),(126,89,5);
GO

PRINT 'Retete bucatarie europeana inserate cu succes!';
GO

USE MojitoDB;

-- Fix 98: Mic dejun englezesc (rosii cherry duplicate)
DELETE FROM Produs_Ingrediente WHERE id_produs = 98 AND id_ingredient = 96;
INSERT INTO Produs_Ingrediente VALUES (98,96,160); -- combinat 60+100

-- Fix 101: Oua pocheat cu somon (somon duplicate)
DELETE FROM Produs_Ingrediente WHERE id_produs = 101 AND id_ingredient = 112;
INSERT INTO Produs_Ingrediente VALUES (101,112,110); -- combinat 60+50

-- Fix 103: Fritto misto (calamar duplicate)
DELETE FROM Produs_Ingrediente WHERE id_produs = 103 AND id_ingredient = 154;
INSERT INTO Produs_Ingrediente VALUES (103,154,165); -- combinat 85+80

-- Fix 108: Crunch Set (sos chili-mayo duplicate)
DELETE FROM Produs_Ingrediente WHERE id_produs = 108 AND id_ingredient = 110;
INSERT INTO Produs_Ingrediente VALUES (108,110,100); -- combinat 50+50

-- Fix 123: Medalion de vita (sare duplicate)
DELETE FROM Produs_Ingrediente WHERE id_produs = 123 AND id_ingredient = 65;
INSERT INTO Produs_Ingrediente VALUES (123,65,3); -- combinat 2+1
GO

PRINT 'Fix-uri aplicate cu succes!';
GO

USE MojitoDB;

-- ============================================================
-- PRODUSE BAR
-- Categorii: id=3 (Cocktailuri & Bar), id=4 (Bauturi Unitare)
-- tip_scadere: premix pentru toate cocktailurile
-- ============================================================

INSERT INTO Produse (nume, id_categorie, pret, gramaj, tip_scadere) VALUES
-- LIMONADE (cat 4, bucata)
('Limonada Piersic-Yuzu',           4, 100.00, '300ml', 'premix'),
('Limonada Zmeura-Lemongrass',      4, 100.00, '300ml', 'premix'),
('Limonada Feijoa-Mar Verde',       4, 100.00, '300ml', 'premix'),
('Limonada Dragon Fruit si Lychee', 4, 100.00, '300ml', 'premix'),
('Limonada Capsuna Alba',           4, 100.00, '300ml', 'premix'),
('Limonada Para si Aloe',           4, 100.00, '300ml', 'premix'),

-- MATCHA DRINKS (cat 4)
('Sifon Grapefruit-Matcha',         4,  85.00, '200ml', 'premix'),
('Sifon Matcha Eclipse',            4,  85.00, '200ml', 'premix'),
('Matcha Pandan-Feijoa',            4,  90.00, '250ml', 'premix'),
('Matcha Mango-Yuzu',               4,  90.00, '250ml', 'premix'),

-- PLACEBO COCKTAILS non-alcoholic (cat 3)
('Yuzu Storm',                      3, 135.00, '150ml', 'premix'),
('Sakura',                          3, 135.00, '150ml', 'premix'),
('Morning Breeze',                  3, 135.00, '120ml', 'premix'),
('Black Pearl',                     3, 135.00, '150ml', 'premix'),

-- APERITIVES (cat 3)
('Rose Gin Tonic',                  3, 135.00, '200ml', 'premix'),
('Yuzu Gin Tonic',                  3, 135.00, '200ml', 'premix'),
('Sencha Spritz',                   3, 135.00, '200ml', 'premix'),
('Aperol Spritz',                   3, 135.00, '200ml', 'premix'),

-- CAMPARI RIF (cat 3)
('Campari Lychee',                  3, 120.00, '180ml', 'premix'),
('Campari Maracuja',                3, 120.00, '180ml', 'premix'),
('Campari Dragon Fruit',            3, 120.00, '180ml', 'premix'),
('Garibaldi',                       3, 120.00, '180ml', 'premix'),

-- SOUR (cat 3)
('Porn Star Martini',               3, 155.00, '150ml', 'premix'),
('Supreme Daiquiri',                3, 145.00, '120ml', 'premix'),
('Bushi Sour',                      3, 145.00, '120ml', 'premix'),
('Japan New York Sour',             3, 145.00, '150ml', 'premix'),
('Cherry Coconut',                  3, 145.00, '120ml', 'premix'),
('Japan Whisky Sour',               3, 145.00, '120ml', 'premix'),
('Pisco Sour',                      3, 155.00, '120ml', 'premix'),
('Tropical Garden',                 3, 145.00, '150ml', 'premix'),
('Gin Basil Smash',                 3, 145.00, '150ml', 'premix'),

-- LONG DRINKS (cat 3)
('Mojito',                          3, 150.00, '200ml', 'premix'),
('Mojito Strawberry',               3, 150.00, '200ml', 'premix'),
('Mojito Peach Yuzu',               3, 150.00, '200ml', 'premix'),
('Classic Mojito',                  3, 150.00, '150ml', 'premix'),
('Classic Strawberry Mojito',       3, 150.00, '150ml', 'premix'),
('Passion Fruit Mojito',            3, 150.00, '150ml', 'premix'),
('Geisha',                          3, 150.00, '200ml', 'premix'),
('Aloe Breeze',                     3, 150.00, '180ml', 'premix'),
('Gold in Glass',                   3, 150.00, '180ml', 'premix'),
('Paloma Sakura',                   3, 150.00, '180ml', 'premix'),
('Harmony',                         3, 150.00, '180ml', 'premix'),

-- STRONG DRINKS (cat 3)
('Star Elixir',                     3, 160.00, '120ml', 'premix'),
('Negroni Foam Colada',             3, 160.00, '120ml', 'premix'),
('Negroni',                         3, 160.00,  '90ml', 'premix');
GO

-- ============================================================
-- INGREDIENTE BAR (premix-uri)
-- ============================================================
INSERT INTO Ingrediente (nume, unitate_masura) VALUES
('Premix Limonada Piersic-Yuzu',        'ml'),  -- 156
('Premix Limonada Zmeura-Lemongrass',   'ml'),  -- 157
('Premix Limonada Feijoa-Mar Verde',    'ml'),  -- 158
('Premix Limonada Dragon Fruit',        'ml'),  -- 159
('Premix Limonada Capsuna Alba',        'ml'),  -- 160
('Premix Limonada Para-Aloe',           'ml'),  -- 161
('Premix Sifon Grapefruit-Matcha',      'ml'),  -- 162
('Premix Sifon Matcha Eclipse',         'ml'),  -- 163
('Premix Matcha Pandan-Feijoa',         'ml'),  -- 164
('Premix Matcha Mango-Yuzu',            'ml'),  -- 165
('Premix Yuzu Storm',                   'ml'),  -- 166
('Premix Sakura',                       'ml'),  -- 167
('Premix Morning Breeze',               'ml'),  -- 168
('Premix Black Pearl',                  'ml'),  -- 169
('Premix Rose Gin Tonic',               'ml'),  -- 170
('Premix Yuzu Gin Tonic',               'ml'),  -- 171
('Premix Sencha Spritz',                'ml'),  -- 172
('Premix Aperol Spritz',                'ml'),  -- 173
('Premix Campari Lychee',               'ml'),  -- 174
('Premix Campari Maracuja',             'ml'),  -- 175
('Premix Campari Dragon Fruit',         'ml'),  -- 176
('Premix Garibaldi',                    'ml'),  -- 177
('Premix Porn Star Martini',            'ml'),  -- 178
('Premix Supreme Daiquiri',             'ml'),  -- 179
('Premix Bushi Sour',                   'ml'),  -- 180
('Premix Japan New York Sour',          'ml'),  -- 181
('Premix Cherry Coconut',               'ml'),  -- 182
('Premix Japan Whisky Sour',            'ml'),  -- 183
('Premix Pisco Sour',                   'ml'),  -- 184
('Premix Tropical Garden',              'ml'),  -- 185
('Premix Gin Basil Smash',              'ml'),  -- 186
('Premix Mojito',                       'ml'),  -- 187
('Premix Mojito Strawberry',            'ml'),  -- 188
('Premix Mojito Peach Yuzu',            'ml'),  -- 189
('Premix Classic Mojito',               'ml'),  -- 190
('Premix Classic Strawberry Mojito',    'ml'),  -- 191
('Premix Passion Fruit Mojito',         'ml'),  -- 192
('Premix Geisha',                       'ml'),  -- 193
('Premix Aloe Breeze',                  'ml'),  -- 194
('Premix Gold in Glass',                'ml'),  -- 195
('Premix Paloma Sakura',                'ml'),  -- 196
('Premix Harmony',                      'ml'),  -- 197
('Premix Star Elixir',                  'ml'),  -- 198
('Premix Negroni Foam Colada',          'ml'),  -- 199
('Premix Negroni',                      'ml');  -- 200
GO

-- Stocuri initiale pentru toate premix-urile (5L fiecare, minim 500ml)
INSERT INTO Stocuri (id_ingredient, cantitate_disponibila, cantitate_minima)
SELECT id, 5000, 500 FROM Ingrediente WHERE id BETWEEN 156 AND 200;
GO

-- Verificare ID-uri produse bar
SELECT id, nume, gramaj FROM Produse 
WHERE id_categorie IN (3,4) AND id > 126
ORDER BY id;
GO

USE MojitoDB;

-- ============================================================
-- RETETE BAR (Produs_Ingrediente)
-- Fiecare cocktail foloseste premix-ul sau in cantitatea = gramajul
-- ID produse: 127-171
-- ID ingrediente premix: 156-200
-- ============================================================

-- LIMONADE (300ml premix fiecare)
INSERT INTO Produs_Ingrediente VALUES (127, 156, 300);
INSERT INTO Produs_Ingrediente VALUES (128, 157, 300);
INSERT INTO Produs_Ingrediente VALUES (129, 158, 300);
INSERT INTO Produs_Ingrediente VALUES (130, 159, 300);
INSERT INTO Produs_Ingrediente VALUES (131, 160, 300);
INSERT INTO Produs_Ingrediente VALUES (132, 161, 300);

-- MATCHA DRINKS
INSERT INTO Produs_Ingrediente VALUES (133, 162, 200);
INSERT INTO Produs_Ingrediente VALUES (134, 163, 200);
INSERT INTO Produs_Ingrediente VALUES (135, 164, 250);
INSERT INTO Produs_Ingrediente VALUES (136, 165, 250);

-- PLACEBO COCKTAILS
INSERT INTO Produs_Ingrediente VALUES (137, 166, 150);
INSERT INTO Produs_Ingrediente VALUES (138, 167, 150);
INSERT INTO Produs_Ingrediente VALUES (139, 168, 120);
INSERT INTO Produs_Ingrediente VALUES (140, 169, 150);

-- APERITIVES
INSERT INTO Produs_Ingrediente VALUES (141, 170, 200);
INSERT INTO Produs_Ingrediente VALUES (142, 171, 200);
INSERT INTO Produs_Ingrediente VALUES (143, 172, 200);
INSERT INTO Produs_Ingrediente VALUES (144, 173, 200);

-- CAMPARI RIF
INSERT INTO Produs_Ingrediente VALUES (145, 174, 180);
INSERT INTO Produs_Ingrediente VALUES (146, 175, 180);
INSERT INTO Produs_Ingrediente VALUES (147, 176, 180);
INSERT INTO Produs_Ingrediente VALUES (148, 177, 180);

-- SOUR
INSERT INTO Produs_Ingrediente VALUES (149, 178, 150);
INSERT INTO Produs_Ingrediente VALUES (150, 179, 120);
INSERT INTO Produs_Ingrediente VALUES (151, 180, 120);
INSERT INTO Produs_Ingrediente VALUES (152, 181, 150);
INSERT INTO Produs_Ingrediente VALUES (153, 182, 120);
INSERT INTO Produs_Ingrediente VALUES (154, 183, 120);
INSERT INTO Produs_Ingrediente VALUES (155, 184, 120);
INSERT INTO Produs_Ingrediente VALUES (156, 185, 150);
INSERT INTO Produs_Ingrediente VALUES (157, 186, 150);

-- LONG DRINKS
INSERT INTO Produs_Ingrediente VALUES (158, 187, 200);
INSERT INTO Produs_Ingrediente VALUES (159, 188, 200);
INSERT INTO Produs_Ingrediente VALUES (160, 189, 200);
INSERT INTO Produs_Ingrediente VALUES (161, 190, 150);
INSERT INTO Produs_Ingrediente VALUES (162, 191, 150);
INSERT INTO Produs_Ingrediente VALUES (163, 192, 150);
INSERT INTO Produs_Ingrediente VALUES (164, 193, 200);
INSERT INTO Produs_Ingrediente VALUES (165, 194, 180);
INSERT INTO Produs_Ingrediente VALUES (166, 195, 180);
INSERT INTO Produs_Ingrediente VALUES (167, 196, 180);
INSERT INTO Produs_Ingrediente VALUES (168, 197, 180);

-- STRONG DRINKS
INSERT INTO Produs_Ingrediente VALUES (169, 198, 120);
INSERT INTO Produs_Ingrediente VALUES (170, 199, 120);
INSERT INTO Produs_Ingrediente VALUES (171, 200,  90);
GO

PRINT 'Retete bar inserate cu succes!';
GO

USE MojitoDB;

-- Adaugam tip nou de scadere pentru vin la pahar
ALTER TABLE Produse DROP CONSTRAINT CK__Produse__tip_sca__3A81B327;

ALTER TABLE Produse ADD CONSTRAINT CK_Produse_tip_scadere 
CHECK (tip_scadere IN ('ingrediente','portie','bucata','premix','manual','pahar'));
GO

USE MojitoDB;

SELECT name FROM sys.check_constraints 
WHERE parent_object_id = OBJECT_ID('Produse');
GO
USE MojitoDB;

ALTER TABLE Produse DROP CONSTRAINT CK__Produse__tip_sca__4222D4EF;

ALTER TABLE Produse ADD CONSTRAINT CK_Produse_tip_scadere 
CHECK (tip_scadere IN ('ingrediente','portie','bucata','premix','manual','pahar'));
GO


USE MojitoDB;

-- ============================================================
-- INGREDIENTE BAUTURI
-- ============================================================
INSERT INTO Ingrediente (nume, unitate_masura) VALUES
-- Cafea & Matcha
('Boabe de cafea',          'g'),    -- 201
('Lapte',                   'ml'),   -- 202
('Lapte vegetal',           'ml'),   -- 203
('Matcha ceremoniala',      'g'),    -- 204
-- Fresh
('Portocale',               'g'),    -- 205
('Lamaie',                  'g'),    -- 206
('Grapefruit',              'g'),    -- 207
-- Ceaiuri Ronfeld
('Ceai negru Ronfeld',      'buc'),  -- 208
('Ceai verde Ronfeld',      'buc'),  -- 209
('Ceai herbal Ronfeld',     'buc'),  -- 210
('Ceai fructe Ronfeld',     'buc'),  -- 211
-- Premix ceaiuri homemade
('Premix Ceai Para-Aloe',           'ml'),  -- 212
('Premix Ceai Capsuna-Yuzu',        'ml'),  -- 213
('Premix Ceai Zmeura-Cocos',        'ml'),  -- 214
('Premix Ceai Catina-Soc',          'ml'),  -- 215
-- Soft Drinks (bucata)
('Coca-Cola 250ml',         'buc'),  -- 216
('Coca-Cola Zero 250ml',    'buc'),  -- 217
('Fanta 250ml',             'buc'),  -- 218
('Sprite 250ml',            'buc'),  -- 219
('Schweppes 250ml',         'buc'),  -- 220
('Dorna 330ml',             'buc'),  -- 221
('Dorna 750ml',             'buc'),  -- 222
('Borjomi 500ml',           'buc'),  -- 223
('Juice 250ml',             'buc'),  -- 224
('Burn Energy 200ml',       'buc'),  -- 225
-- Spirtoase (ml in stoc)
('Macallan Double Cask 15YO',       'ml'),  -- 226
('Macallan Triple Cask 12YO',       'ml'),  -- 227
('Chivas Regal 18YO',               'ml'),  -- 228
('Glenfiddich 12YO',                'ml'),  -- 229
('Glenfiddich 15YO',                'ml'),  -- 230
('Glenmorangie Quinta Ruban 14YO',  'ml'),  -- 231
('Glenmorangie Lasanta 12YO',       'ml'),  -- 232
('Glenmorangie Original 10YO',      'ml'),  -- 233
('Chivas Regal 12YO',               'ml'),  -- 234
('Johnnie Walker Red Label',        'ml'),  -- 235
('Johnnie Walker Black Label',      'ml'),  -- 236
('Monkey Shoulder',                 'ml'),  -- 237
('Tullamore Dew 12YO',              'ml'),  -- 238
('Tullamore Dew',                   'ml'),  -- 239
('Jameson',                         'ml'),  -- 240
('Jack Daniels Single Barrel',      'ml'),  -- 241
('Jack Daniels Old No7',            'ml'),  -- 242
('Jack Daniels Tennessee Honey',    'ml'),  -- 243
('Jim Beam',                        'ml'),  -- 244
('Evan Williams',                   'ml'),  -- 245
('Evan Williams Single Barrel',     'ml'),  -- 246
('The Kurayoshi',                   'ml'),  -- 247
('Fuyu',                            'ml'),  -- 248
('Fujimi',                          'ml'),  -- 249
('Akashi-Tai',                      'ml'),  -- 250
('Plantation Pineapple',            'ml'),  -- 251
('Plantation 3 Stars',              'ml'),  -- 252
('Bacardi 8YO',                     'ml'),  -- 253
('Bacardi Carta Blanca',            'ml'),  -- 254
('Grey Goose',                      'ml'),  -- 255
('Belvedere',                       'ml'),  -- 256
('Finlandia',                       'ml'),  -- 257
('Khortytsa Premium',               'ml'),  -- 258
('Gin Mare Capri',                  'ml'),  -- 259
('Drumshanbo Gunpowder',            'ml'),  -- 260
('135 East Hyogo Dry Gin',          'ml'),  -- 261
('Hendricks',                       'ml'),  -- 262
('Citadelle Original',              'ml'),  -- 263
('Citadelle Reserve',               'ml'),  -- 264
('Bombay Sapphire',                 'ml'),  -- 265
('Tanqueray',                       'ml'),  -- 266
('Azul Reposado',                   'ml'),  -- 267
('Azul Plata',                      'ml'),  -- 268
('Kah Tequila',                     'ml'),  -- 269
('Roster Rojo',                     'ml'),  -- 270
('Jose Cuervo',                     'ml'),  -- 271
('Hennessy XO',                     'ml'),  -- 272
('Hennessy VSOP',                   'ml'),  -- 273
('Hennessy VS',                     'ml'),  -- 274
('Pierre Ferrand 10Gen',            'ml'),  -- 275
('Pierre Ferrand',                  'ml'),  -- 276
('Bardar 20YO',                     'ml'),  -- 277
('Bardar 15YO',                     'ml'),  -- 278
('Bardar 12YO',                     'ml'),  -- 279
('Bardar 10YO',                     'ml'),  -- 280
('Bardar 7YO',                      'ml'),  -- 281
('Bardar 5YO',                      'ml'),  -- 282
-- Bere draft (ml in stoc)
('Hopfenbrau AGA',                  'ml'),  -- 283
('Hoegaarden',                      'ml'),  -- 284
('Kozel',                           'ml'),  -- 285
-- Bere la sticla (bucata)
('Corona Extra 350ml',              'buc'), -- 286
('Corona Zero 350ml',               'buc'), -- 287
('Franziskaner 500ml',              'buc'), -- 288
-- Vin & Sampanie la sticla (bucata)
('Dom Perignon 750ml',              'buc'), -- 289
('Veuve Clicquot Brut 750ml',       'buc'), -- 290
('Veuve Clicquot Rose 750ml',       'buc'), -- 291
('Moet Chandon 750ml',              'buc'), -- 292
('Moet Chandon Mini 200ml',         'buc'), -- 293
('Martini Asti 750ml',              'buc'), -- 294
('Cricova Grand Vintage 750ml',     'buc'), -- 295
('Brut Natur Elogiu 750ml',         'buc'), -- 296
('Cricova Cuvee Prestige 750ml',    'buc'), -- 297
('Cricova Crisecco 750ml',          'buc'), -- 298
('Cricova Crisecco 375ml',          'buc'), -- 299
('Cricova Lacrima Dulce 750ml',     'buc'), -- 300
('Cricova Lacrima Dulce 375ml',     'buc'), -- 301
('Grande Cuvee Purcari 750ml',      'buc'), -- 302
('Cuvee Purcari Alb 750ml',         'buc'), -- 303
('Cuvee Purcari Rose 750ml',        'buc'), -- 304
('Maestro Prosecco 750ml',          'buc'), -- 305
('Prosecco Bottega Gold 750ml',     'buc'), -- 306
('Prosecco Bottega Poeti 750ml',    'buc'), -- 307
('Cricova Elogiu Chardonnay 750ml', 'buc'), -- 308
('Cricova Elogiu Sapte Soiuri 750ml','buc'),-- 309
('Cricova Virgin 750ml',            'buc'), -- 310
('Cricova Cabernet 750ml',          'buc'), -- 311
('Cricova Codru 750ml',             'buc'), -- 312
('Cricova Pinot Grigio 750ml',      'buc'), -- 313
('Cricova Chardonnay 750ml',        'buc'), -- 314
('Cricova Rose 750ml',              'buc'), -- 315
('Cricova Shiraz 750ml',            'buc'), -- 316
('Cricova Magnific 750ml',          'buc'), -- 317
('Cricova Tatius 750ml',            'buc'), -- 318
('Negru Purcari Vintage 750ml',     'buc'), -- 319
('Rosu Purcari 750ml',              'buc'), -- 320
('Negru Purcari 750ml',             'buc'), -- 321
('Alb Purcari 750ml',               'buc'), -- 322
('Purcari Traminer 750ml',          'buc'), -- 323
('Purcari Pinot Gri 750ml',         'buc'), -- 324
('Purcari Saperavi 750ml',          'buc'), -- 325
('Purcari Malbec 750ml',            'buc'), -- 326
('Viorica Purcari 750ml',           'buc'), -- 327
('Rose Purcari 750ml',              'buc'), -- 328
('Pinot Grigio Purcari 750ml',      'buc'), -- 329
('Chardonnay Purcari 750ml',        'buc'), -- 330
('Cabernet Sauvignon Purcari 750ml','buc'), -- 331
-- Vin la pahar (sticle in stoc, scade 0.2 per pahar)
('Cricova Codru sticla',            'buc'), -- 332
('Cricova Rose sticla',             'buc'), -- 333
('Cricova Chardonnay sticla',       'buc'), -- 334
('Rose Purcari sticla',             'buc'), -- 335
('Cabernet Purcari sticla',         'buc'), -- 336
('Pinot Grigio Purcari sticla',     'buc'); -- 337
GO

-- Stocuri initiale
-- Cafea, matcha, fresh
INSERT INTO Stocuri (id_ingredient, cantitate_disponibila, cantitate_minima) VALUES
(201, 1000, 100),   -- boabe cafea 1kg
(202, 5000, 500),   -- lapte 5L
(203, 3000, 300),   -- lapte vegetal 3L
(204, 500,  50),    -- matcha 500g
(205, 5000, 500),   -- portocale 5kg
(206, 3000, 300),   -- lamaie 3kg
(207, 4000, 400);   -- grapefruit 4kg
-- Ceaiuri Ronfeld
INSERT INTO Stocuri (id_ingredient, cantitate_disponibila, cantitate_minima) VALUES
(208, 100, 10),(209, 100, 10),(210, 100, 10),(211, 100, 10);
-- Premix ceaiuri homemade
INSERT INTO Stocuri (id_ingredient, cantitate_disponibila, cantitate_minima) VALUES
(212,5000,500),(213,5000,500),(214,5000,500),(215,5000,500);
-- Soft drinks (bucati)
INSERT INTO Stocuri (id_ingredient, cantitate_disponibila, cantitate_minima) VALUES
(216,48,6),(217,48,6),(218,48,6),(219,48,6),(220,48,6),
(221,48,6),(222,24,3),(223,24,3),(224,48,6),(225,24,3);
-- Spirtoase (ml - 6 sticle x 700ml = 4200ml implicit)
INSERT INTO Stocuri (id_ingredient, cantitate_disponibila, cantitate_minima)
SELECT id, 4200, 700 FROM Ingrediente WHERE id BETWEEN 226 AND 282;
-- Bere draft (ml - 100L = 100000ml)
INSERT INTO Stocuri (id_ingredient, cantitate_disponibila, cantitate_minima) VALUES
(283,100000,5000),(284,100000,5000),(285,100000,5000);
-- Bere sticla (bucati)
INSERT INTO Stocuri (id_ingredient, cantitate_disponibila, cantitate_minima) VALUES
(286,24,3),(287,24,3),(288,24,3);
-- Vin & Sampanie la sticla (bucati)
INSERT INTO Stocuri (id_ingredient, cantitate_disponibila, cantitate_minima)
SELECT id, 10, 1 FROM Ingrediente WHERE id BETWEEN 289 AND 331;
-- Vin la pahar (sticle)
INSERT INTO Stocuri (id_ingredient, cantitate_disponibila, cantitate_minima) VALUES
(332,5,1),(333,5,1),(334,5,1),(335,5,1),(336,5,1),(337,5,1);
GO

-- ============================================================
-- PRODUSE BAUTURI
-- ============================================================
INSERT INTO Produse (nume, id_categorie, pret, gramaj, tip_scadere) VALUES
-- CEAIURI HOMEMADE (cat 4, premix)
('Ceai Para si Aloe',               4, 110.00, '500ml', 'premix'),
('Ceai Capsuna si Yuzu',            4, 110.00, '500ml', 'premix'),
('Ceai Zmeura cu Cocos',            4, 110.00, '500ml', 'premix'),
('Ceai Catina si Soc',              4, 110.00, '500ml', 'premix'),
-- CAFEA (cat 4, ingrediente)
('Espresso',                        4,  40.00,  '30ml', 'ingrediente'),
('Americano',                       4,  40.00,  '90ml', 'ingrediente'),
('Cappuccino',                      4,  60.00, '250ml', 'ingrediente'),
('Vegan Cappuccino',                4,  75.00, '250ml', 'ingrediente'),
('Coffee Latte',                    4,  60.00, '250ml', 'ingrediente'),
('Caffe Latte Vegan',               4,  75.00, '250ml', 'ingrediente'),
('Matcha Latte',                    4,  70.00, '250ml', 'ingrediente'),
-- CEAIURI RONFELD (cat 4, bucata)
('Ronfeld Black Tea',               4,  65.00, '400ml', 'bucata'),
('Ronfeld Green Tea',               4,  65.00, '400ml', 'bucata'),
('Ronfeld Herbal Tea',              4,  65.00, '400ml', 'bucata'),
('Ronfeld Fruit Tea',               4,  65.00, '400ml', 'bucata'),
-- FRESH JUICE (cat 4, ingrediente)
('Orange Fresh',                    4,  85.00, '250ml', 'ingrediente'),
('Grapefruit Fresh',                4,  85.00, '250ml', 'ingrediente'),
('Lemon Fresh',                     4,  85.00, '250ml', 'ingrediente'),
('Mix Fresh',                       4,  85.00, '250ml', 'ingrediente'),
-- SOFT DRINKS (cat 4, bucata)
('Coca-Cola',                       4,  40.00, '250ml', 'bucata'),
('Coca-Cola Zero',                  4,  40.00, '250ml', 'bucata'),
('Fanta',                           4,  40.00, '250ml', 'bucata'),
('Sprite',                          4,  40.00, '250ml', 'bucata'),
('Schweppes',                       4,  40.00, '250ml', 'bucata'),
('Dorna 330ml',                     4,  45.00, '330ml', 'bucata'),
('Dorna 750ml',                     4,  85.00, '750ml', 'bucata'),
('Borjomi',                         4,  85.00, '500ml', 'bucata'),
('Juice',                           4,  45.00, '250ml', 'bucata'),
('Burn Energy',                     4,  75.00, '200ml', 'bucata'),
-- SCOTCH WHISKY (cat 5, portie 40ml)
('Macallan Double Cask 15 Y.O.',    5, 280.00, '40ml',  'portie'),
('Macallan Triple Cask 12 Y.O.',    5, 180.00, '40ml',  'portie'),
('Chivas Regal 18 Y.O.',            5, 250.00, '40ml',  'portie'),
('Glenfiddich 12 Y.O.',             5, 145.00, '40ml',  'portie'),
('Glenfiddich 15 Y.O.',             5, 195.00, '40ml',  'portie'),
('Glenmorangie Quinta Ruban 14 Y.O.',5,155.00, '40ml',  'portie'),
('Glenmorangie Lasanta 12 Y.O.',    5, 135.00, '40ml',  'portie'),
('Glenmorangie Original 10 Y.O.',   5, 115.00, '40ml',  'portie'),
('Chivas Regal 12 Y.O.',            5, 115.00, '40ml',  'portie'),
('Johnnie Walker Red Label',        5,  65.00, '40ml',  'portie'),
('Johnnie Walker Black Label',      5, 100.00, '40ml',  'portie'),
('Monkey Shoulder',                 5, 100.00, '40ml',  'portie'),
-- IRISH WHISKY
('Tullamore Dew 12 Y.O.',           5, 105.00, '40ml',  'portie'),
('Tullamore Dew',                   5,  65.00, '40ml',  'portie'),
('Jameson',                         5,  75.00, '40ml',  'portie'),
-- AMERICAN WHISKEY
('Jack Daniels Single Barrel',      5, 120.00, '40ml',  'portie'),
('Jack Daniels Old No.7',           5,  70.00, '40ml',  'portie'),
('Jack Daniels Tennessee Honey',    5,  70.00, '40ml',  'portie'),
('Jim Beam',                        5,  70.00, '40ml',  'portie'),
('Evan Williams',                   5,  70.00, '40ml',  'portie'),
('Evan Williams Single Barrel',     5, 100.00, '40ml',  'portie'),
-- JAPANESE WHISKEY
('The Kurayoshi',                   5, 150.00, '40ml',  'portie'),
('Fuyu',                            5, 105.00, '40ml',  'portie'),
('Fujimi',                          5, 120.00, '40ml',  'portie'),
('Akashi-Tai',                      5,  90.00, '40ml',  'portie'),
-- RUM
('Plantation Pineapple',            5, 100.00, '40ml',  'portie'),
('Plantation 3 Stars',              5,  65.00, '40ml',  'portie'),
('Bacardi 8 Year Old',              5,  90.00, '40ml',  'portie'),
('Bacardi Carta Blanca',            5,  65.00, '40ml',  'portie'),
-- VODCA
('Grey Goose',                      5, 110.00, '40ml',  'portie'),
('Belvedere',                       5,  95.00, '40ml',  'portie'),
('Finlandia',                       5,  65.00, '40ml',  'portie'),
('Khortytsa Premium',               5,  55.00, '40ml',  'portie'),
-- GIN
('Gin Mare Capri',                  5, 120.00, '40ml',  'portie'),
('Drumshanbo Gunpowder',            5, 105.00, '40ml',  'portie'),
('135 East Hyogo Dry Gin',          5,  95.00, '40ml',  'portie'),
('Hendricks',                       5, 110.00, '40ml',  'portie'),
('Citadelle Original',              5,  85.00, '40ml',  'portie'),
('Citadelle Reserve',               5, 105.00, '40ml',  'portie'),
('Bombay Sapphire',                 5,  75.00, '40ml',  'portie'),
('Tanqueray',                       5,  75.00, '40ml',  'portie'),
-- TEQUILA
('Azul Reposado',                   5, 440.00, '40ml',  'portie'),
('Azul Plata',                      5, 275.00, '40ml',  'portie'),
('Kah Tequila',                     5, 140.00, '40ml',  'portie'),
('Roster Rojo',                     5,  95.00, '40ml',  'portie'),
('Jose Cuervo',                     5,  75.00, '40ml',  'portie'),
-- CONIAC
('Hennessy X.O.',                   5, 490.00, '40ml',  'portie'),
('Hennessy V.S.O.P.',               5, 150.00, '40ml',  'portie'),
('Hennessy Very Special',           5, 120.00, '40ml',  'portie'),
('Pierre Ferrand 10 Generations',   5, 130.00, '40ml',  'portie'),
('Pierre Ferrand',                  5,  90.00, '40ml',  'portie'),
-- DIVIN MOLDOVENESC
('Bardar 20 Y.O.',                  5, 280.00, '40ml',  'portie'),
('Bardar 15 Y.O.',                  5, 180.00, '40ml',  'portie'),
('Bardar 12 Y.O.',                  5,  95.00, '40ml',  'portie'),
('Bardar 10 Y.O.',                  5,  85.00, '40ml',  'portie'),
('Bardar 7 Y.O.',                   5,  70.00, '40ml',  'portie'),
('Bardar 5 Y.O.',                   5,  60.00, '40ml',  'portie'),
-- BERE DRAFT (portie 400ml)
('Hopfenbrau AGA',                  5,  65.00, '400ml', 'portie'),
('Hoegaarden',                      5,  90.00, '400ml', 'portie'),
('Kozel',                           5,  65.00, '400ml', 'portie'),
-- BERE STICLA (bucata)
('Corona Extra',                    5,  90.00, '350ml', 'bucata'),
('Corona Zero',                     5,  90.00, '350ml', 'bucata'),
('Franziskaner Weissbier',          5,  95.00, '500ml', 'bucata'),
-- SAMPANIE & VIN SPUMANT la sticla (bucata)
('Dom Perignon',                    6,7500.00, '750ml', 'bucata'),
('Veuve Clicquot Brut',             6,2300.00, '750ml', 'bucata'),
('Veuve Clicquot Rose',             6,2600.00, '750ml', 'bucata'),
('Moet & Chandon',                  6,2200.00, '750ml', 'bucata'),
('Moet & Chandon Mini',             6, 490.00, '200ml', 'bucata'),
('Martini Asti',                    6, 600.00, '750ml', 'bucata'),
('Cricova Grand Vintage',           6, 990.00, '750ml', 'bucata'),
('Brut Natur Elogiu',               6, 650.00, '750ml', 'bucata'),
('Cricova Cuvee Prestige',          6, 550.00, '750ml', 'bucata'),
('Cricova Crisecco 750ml',          6, 315.00, '750ml', 'bucata'),
('Cricova Crisecco 375ml',          6, 150.00, '375ml', 'bucata'),
('Cricova Lacrima Dulce 750ml',     6, 315.00, '750ml', 'bucata'),
('Cricova Lacrima Dulce 375ml',     6, 150.00, '375ml', 'bucata'),
('Grande Cuvee de Purcari',         6, 800.00, '750ml', 'bucata'),
('Cuvee de Purcari Alb',            6, 600.00, '750ml', 'bucata'),
('Cuvee de Purcari Rose',           6, 650.00, '750ml', 'bucata'),
('Maestro Prosecco',                6, 390.00, '750ml', 'bucata'),
('Prosecco Bottega Gold',           6, 990.00, '750ml', 'bucata'),
('Prosecco Bottega Poeti',          6, 610.00, '750ml', 'bucata'),
-- VIN la sticla (bucata)
('Cricova Elogiu Chardonnay',       6, 690.00, '750ml', 'bucata'),
('Cricova Elogiu Sapte Soiuri',     6, 650.00, '750ml', 'bucata'),
('Cricova Virgin',                  6, 540.00, '750ml', 'bucata'),
('Cricova Cabernet',                6, 350.00, '750ml', 'bucata'),
('Cricova Codru',                   6, 350.00, '750ml', 'bucata'),
('Cricova Pinot Grigio',            6, 350.00, '750ml', 'bucata'),
('Cricova Chardonnay',              6, 350.00, '750ml', 'bucata'),
('Cricova Rose de Cricova',         6, 350.00, '750ml', 'bucata'),
('Cricova Shiraz Prestige',         6, 370.00, '750ml', 'bucata'),
('Cricova Magnific',                6, 480.00, '750ml', 'bucata'),
('Cricova Tatius',                  6, 690.00, '750ml', 'bucata'),
('Negru de Purcari Vintage',        6,1200.00, '750ml', 'bucata'),
('Rosu de Purcari',                 6, 850.00, '750ml', 'bucata'),
('Negru de Purcari',                6, 850.00, '750ml', 'bucata'),
('Alb de Purcari',                  6, 850.00, '750ml', 'bucata'),
('Purcari Traminer',                6, 490.00, '750ml', 'bucata'),
('Purcari Pinot Gri',               6, 490.00, '750ml', 'bucata'),
('Purcari Saperavi',                6, 490.00, '750ml', 'bucata'),
('Purcari Malbec',                  6, 490.00, '750ml', 'bucata'),
('Viorica de Purcari',              6, 425.00, '750ml', 'bucata'),
('Rose de Purcari',                 6, 425.00, '750ml', 'bucata'),
('Pinot Grigio de Purcari',         6, 425.00, '750ml', 'bucata'),
('Chardonnay de Purcari',           6, 425.00, '750ml', 'bucata'),
('Cabernet Sauvignon de Purcari',   6, 425.00, '750ml', 'bucata'),
-- VIN LA PAHAR (pahar = 1/5 sticla)
('Cricova Codru pahar',             6,  70.00, '150ml', 'pahar'),
('Cricova Rose pahar',              6,  70.00, '150ml', 'pahar'),
('Cricova Chardonnay pahar',        6,  70.00, '150ml', 'pahar'),
('Rose de Purcari pahar',           6,  85.00, '150ml', 'pahar'),
('Cabernet de Purcari pahar',       6,  85.00, '150ml', 'pahar'),
('Pinot Grigio de Purcari pahar',   6,  85.00, '150ml', 'pahar');
GO

-- Verificare
SELECT COUNT(*) AS total_produse_bauturi 
FROM Produse WHERE id_categorie IN (4,5,6) AND id > 171;
GO

USE MojitoDB;
SELECT id, nume, tip_scadere FROM Produse 
WHERE id_categorie IN (4,5,6) AND id > 171
ORDER BY id;
GO


USE MojitoDB;

-- ============================================================
-- RETETE BAUTURI (Produs_Ingrediente)
-- ============================================================

-- CEAIURI HOMEMADE (premix 500ml)
INSERT INTO Produs_Ingrediente VALUES (172, 212, 500);
INSERT INTO Produs_Ingrediente VALUES (173, 213, 500);
INSERT INTO Produs_Ingrediente VALUES (174, 214, 500);
INSERT INTO Produs_Ingrediente VALUES (175, 215, 500);

-- CAFEA
-- Espresso (8g boabe)
INSERT INTO Produs_Ingrediente VALUES (176, 201, 8);
-- Americano (8g boabe)
INSERT INTO Produs_Ingrediente VALUES (177, 201, 8);
-- Cappuccino (8g boabe + 200ml lapte)
INSERT INTO Produs_Ingrediente VALUES (178, 201, 8);
INSERT INTO Produs_Ingrediente VALUES (178, 202, 200);
-- Vegan Cappuccino (8g boabe + 200ml lapte vegetal)
INSERT INTO Produs_Ingrediente VALUES (179, 201, 8);
INSERT INTO Produs_Ingrediente VALUES (179, 203, 200);
-- Coffee Latte (8g boabe + 220ml lapte)
INSERT INTO Produs_Ingrediente VALUES (180, 201, 8);
INSERT INTO Produs_Ingrediente VALUES (180, 202, 220);
-- Caffe Latte Vegan (8g boabe + 220ml lapte vegetal)
INSERT INTO Produs_Ingrediente VALUES (181, 201, 8);
INSERT INTO Produs_Ingrediente VALUES (181, 203, 220);
-- Matcha Latte (4g matcha + 220ml lapte)
INSERT INTO Produs_Ingrediente VALUES (182, 204, 4);
INSERT INTO Produs_Ingrediente VALUES (182, 202, 220);

-- CEAIURI RONFELD (1 plic = 1 bucata)
INSERT INTO Produs_Ingrediente VALUES (183, 208, 1);
INSERT INTO Produs_Ingrediente VALUES (184, 209, 1);
INSERT INTO Produs_Ingrediente VALUES (185, 210, 1);
INSERT INTO Produs_Ingrediente VALUES (186, 211, 1);

-- FRESH JUICE
-- Orange Fresh (3 portocale = 450g)
INSERT INTO Produs_Ingrediente VALUES (187, 205, 450);
-- Grapefruit Fresh (2 grapefruituri = 400g)
INSERT INTO Produs_Ingrediente VALUES (188, 207, 400);
-- Lemon Fresh (4 lamai = 300g)
INSERT INTO Produs_Ingrediente VALUES (189, 206, 300);
-- Mix Fresh (1 portocala + 1 grapefruit + 1 lamaie)
INSERT INTO Produs_Ingrediente VALUES (190, 205, 150);
INSERT INTO Produs_Ingrediente VALUES (190, 207, 200);
INSERT INTO Produs_Ingrediente VALUES (190, 206, 75);

-- SOFT DRINKS (1 bucata)
INSERT INTO Produs_Ingrediente VALUES (191, 216, 1);
INSERT INTO Produs_Ingrediente VALUES (192, 217, 1);
INSERT INTO Produs_Ingrediente VALUES (193, 218, 1);
INSERT INTO Produs_Ingrediente VALUES (194, 219, 1);
INSERT INTO Produs_Ingrediente VALUES (195, 220, 1);
INSERT INTO Produs_Ingrediente VALUES (196, 221, 1);
INSERT INTO Produs_Ingrediente VALUES (197, 222, 1);
INSERT INTO Produs_Ingrediente VALUES (198, 223, 1);
INSERT INTO Produs_Ingrediente VALUES (199, 224, 1);
INSERT INTO Produs_Ingrediente VALUES (200, 225, 1);

-- SCOTCH WHISKY (40ml per portie)
INSERT INTO Produs_Ingrediente VALUES (201, 226, 40);
INSERT INTO Produs_Ingrediente VALUES (202, 227, 40);
INSERT INTO Produs_Ingrediente VALUES (203, 228, 40);
INSERT INTO Produs_Ingrediente VALUES (204, 229, 40);
INSERT INTO Produs_Ingrediente VALUES (205, 230, 40);
INSERT INTO Produs_Ingrediente VALUES (206, 231, 40);
INSERT INTO Produs_Ingrediente VALUES (207, 232, 40);
INSERT INTO Produs_Ingrediente VALUES (208, 233, 40);
INSERT INTO Produs_Ingrediente VALUES (209, 234, 40);
INSERT INTO Produs_Ingrediente VALUES (210, 235, 40);
INSERT INTO Produs_Ingrediente VALUES (211, 236, 40);
INSERT INTO Produs_Ingrediente VALUES (212, 237, 40);

-- IRISH WHISKY
INSERT INTO Produs_Ingrediente VALUES (213, 238, 40);
INSERT INTO Produs_Ingrediente VALUES (214, 239, 40);
INSERT INTO Produs_Ingrediente VALUES (215, 240, 40);

-- AMERICAN WHISKEY
INSERT INTO Produs_Ingrediente VALUES (216, 241, 40);
INSERT INTO Produs_Ingrediente VALUES (217, 242, 40);
INSERT INTO Produs_Ingrediente VALUES (218, 243, 40);
INSERT INTO Produs_Ingrediente VALUES (219, 244, 40);
INSERT INTO Produs_Ingrediente VALUES (220, 245, 40);
INSERT INTO Produs_Ingrediente VALUES (221, 246, 40);

-- JAPANESE WHISKEY
INSERT INTO Produs_Ingrediente VALUES (222, 247, 40);
INSERT INTO Produs_Ingrediente VALUES (223, 248, 40);
INSERT INTO Produs_Ingrediente VALUES (224, 249, 40);
INSERT INTO Produs_Ingrediente VALUES (225, 250, 40);

-- RUM
INSERT INTO Produs_Ingrediente VALUES (226, 251, 40);
INSERT INTO Produs_Ingrediente VALUES (227, 252, 40);
INSERT INTO Produs_Ingrediente VALUES (228, 253, 40);
INSERT INTO Produs_Ingrediente VALUES (229, 254, 40);

-- VODCA
INSERT INTO Produs_Ingrediente VALUES (230, 255, 40);
INSERT INTO Produs_Ingrediente VALUES (231, 256, 40);
INSERT INTO Produs_Ingrediente VALUES (232, 257, 40);
INSERT INTO Produs_Ingrediente VALUES (233, 258, 40);

-- GIN
INSERT INTO Produs_Ingrediente VALUES (234, 259, 40);
INSERT INTO Produs_Ingrediente VALUES (235, 260, 40);
INSERT INTO Produs_Ingrediente VALUES (236, 261, 40);
INSERT INTO Produs_Ingrediente VALUES (237, 262, 40);
INSERT INTO Produs_Ingrediente VALUES (238, 263, 40);
INSERT INTO Produs_Ingrediente VALUES (239, 264, 40);
INSERT INTO Produs_Ingrediente VALUES (240, 265, 40);
INSERT INTO Produs_Ingrediente VALUES (241, 266, 40);

-- TEQUILA
INSERT INTO Produs_Ingrediente VALUES (242, 267, 40);
INSERT INTO Produs_Ingrediente VALUES (243, 268, 40);
INSERT INTO Produs_Ingrediente VALUES (244, 269, 40);
INSERT INTO Produs_Ingrediente VALUES (245, 270, 40);
INSERT INTO Produs_Ingrediente VALUES (246, 271, 40);

-- CONIAC
INSERT INTO Produs_Ingrediente VALUES (247, 272, 40);
INSERT INTO Produs_Ingrediente VALUES (248, 273, 40);
INSERT INTO Produs_Ingrediente VALUES (249, 274, 40);
INSERT INTO Produs_Ingrediente VALUES (250, 275, 40);
INSERT INTO Produs_Ingrediente VALUES (251, 276, 40);

-- DIVIN MOLDOVENESC
INSERT INTO Produs_Ingrediente VALUES (252, 277, 40);
INSERT INTO Produs_Ingrediente VALUES (253, 278, 40);
INSERT INTO Produs_Ingrediente VALUES (254, 279, 40);
INSERT INTO Produs_Ingrediente VALUES (255, 280, 40);
INSERT INTO Produs_Ingrediente VALUES (256, 281, 40);
INSERT INTO Produs_Ingrediente VALUES (257, 282, 40);

-- BERE DRAFT (400ml per portie)
INSERT INTO Produs_Ingrediente VALUES (258, 283, 400);
INSERT INTO Produs_Ingrediente VALUES (259, 284, 400);
INSERT INTO Produs_Ingrediente VALUES (260, 285, 400);

-- BERE STICLA (1 bucata)
INSERT INTO Produs_Ingrediente VALUES (261, 286, 1);
INSERT INTO Produs_Ingrediente VALUES (262, 287, 1);
INSERT INTO Produs_Ingrediente VALUES (263, 288, 1);

-- SAMPANIE & VIN SPUMANT la sticla (1 bucata)
INSERT INTO Produs_Ingrediente VALUES (264, 289, 1);
INSERT INTO Produs_Ingrediente VALUES (265, 290, 1);
INSERT INTO Produs_Ingrediente VALUES (266, 291, 1);
INSERT INTO Produs_Ingrediente VALUES (267, 292, 1);
INSERT INTO Produs_Ingrediente VALUES (268, 293, 1);
INSERT INTO Produs_Ingrediente VALUES (269, 294, 1);
INSERT INTO Produs_Ingrediente VALUES (270, 295, 1);
INSERT INTO Produs_Ingrediente VALUES (271, 296, 1);
INSERT INTO Produs_Ingrediente VALUES (272, 297, 1);
INSERT INTO Produs_Ingrediente VALUES (273, 298, 1);
INSERT INTO Produs_Ingrediente VALUES (274, 299, 1);
INSERT INTO Produs_Ingrediente VALUES (275, 300, 1);
INSERT INTO Produs_Ingrediente VALUES (276, 301, 1);
INSERT INTO Produs_Ingrediente VALUES (277, 302, 1);
INSERT INTO Produs_Ingrediente VALUES (278, 303, 1);
INSERT INTO Produs_Ingrediente VALUES (279, 304, 1);
INSERT INTO Produs_Ingrediente VALUES (280, 305, 1);
INSERT INTO Produs_Ingrediente VALUES (281, 306, 1);
INSERT INTO Produs_Ingrediente VALUES (282, 307, 1);

-- VIN LA STICLA (1 bucata)
INSERT INTO Produs_Ingrediente VALUES (283, 308, 1);
INSERT INTO Produs_Ingrediente VALUES (284, 309, 1);
INSERT INTO Produs_Ingrediente VALUES (285, 310, 1);
INSERT INTO Produs_Ingrediente VALUES (286, 311, 1);
INSERT INTO Produs_Ingrediente VALUES (287, 312, 1);
INSERT INTO Produs_Ingrediente VALUES (288, 313, 1);
INSERT INTO Produs_Ingrediente VALUES (289, 314, 1);
INSERT INTO Produs_Ingrediente VALUES (290, 315, 1);
INSERT INTO Produs_Ingrediente VALUES (291, 316, 1);
INSERT INTO Produs_Ingrediente VALUES (292, 317, 1);
INSERT INTO Produs_Ingrediente VALUES (293, 318, 1);
INSERT INTO Produs_Ingrediente VALUES (294, 319, 1);
INSERT INTO Produs_Ingrediente VALUES (295, 320, 1);
INSERT INTO Produs_Ingrediente VALUES (296, 321, 1);
INSERT INTO Produs_Ingrediente VALUES (297, 322, 1);
INSERT INTO Produs_Ingrediente VALUES (298, 323, 1);
INSERT INTO Produs_Ingrediente VALUES (299, 324, 1);
INSERT INTO Produs_Ingrediente VALUES (300, 325, 1);
INSERT INTO Produs_Ingrediente VALUES (301, 326, 1);
INSERT INTO Produs_Ingrediente VALUES (302, 327, 1);
INSERT INTO Produs_Ingrediente VALUES (303, 328, 1);
INSERT INTO Produs_Ingrediente VALUES (304, 329, 1);
INSERT INTO Produs_Ingrediente VALUES (305, 330, 1);
INSERT INTO Produs_Ingrediente VALUES (306, 331, 1);

-- VIN LA PAHAR (0.2 dintr-o sticla = 1/5)
-- Folosim cantitate 0.2 (fractie din sticla)
INSERT INTO Produs_Ingrediente VALUES (307, 332, 1);
INSERT INTO Produs_Ingrediente VALUES (308, 333, 1);
INSERT INTO Produs_Ingrediente VALUES (309, 334, 1);
INSERT INTO Produs_Ingrediente VALUES (310, 335, 1);
INSERT INTO Produs_Ingrediente VALUES (311, 336, 1);
INSERT INTO Produs_Ingrediente VALUES (312, 337, 1);
GO

-- Acum trebuie sa actualizam stored procedure pentru a gestiona
-- tipul 'pahar' (scade 0.2 din stoc) si 'portie' cu cantitati variabile
CREATE OR ALTER PROCEDURE sp_ScadeStocDupaVanzare
    @id_vanzare INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. INGREDIENTE si PREMIX: scade exact cantitatea din reteta x nr portii vandute
    UPDATE S
    SET S.cantitate_disponibila = S.cantitate_disponibila
        - (PI.cantitate * DV.cantitate)
    FROM Stocuri S
    INNER JOIN Produs_Ingrediente PI ON S.id_ingredient = PI.id_ingredient
    INNER JOIN Detalii_Vanzari DV   ON PI.id_produs = DV.id_produs
    INNER JOIN Produse P            ON DV.id_produs = P.id
    WHERE DV.id_vanzare = @id_vanzare
      AND P.tip_scadere IN ('ingrediente', 'premix');

    -- 2. PORTIE: scade cantitatea din reteta (40ml whisky, 400ml bere etc.)
    UPDATE S
    SET S.cantitate_disponibila = S.cantitate_disponibila
        - (PI.cantitate * DV.cantitate)
    FROM Stocuri S
    INNER JOIN Produs_Ingrediente PI ON S.id_ingredient = PI.id_ingredient
    INNER JOIN Detalii_Vanzari DV   ON PI.id_produs = DV.id_produs
    INNER JOIN Produse P            ON DV.id_produs = P.id
    WHERE DV.id_vanzare = @id_vanzare
      AND P.tip_scadere = 'portie';

    -- 3. BUCATA: scade 1 bucata per unitate vanduta
    UPDATE S
    SET S.cantitate_disponibila = S.cantitate_disponibila
        - (PI.cantitate * DV.cantitate)
    FROM Stocuri S
    INNER JOIN Produs_Ingrediente PI ON S.id_ingredient = PI.id_ingredient
    INNER JOIN Detalii_Vanzari DV   ON PI.id_produs = DV.id_produs
    INNER JOIN Produse P            ON DV.id_produs = P.id
    WHERE DV.id_vanzare = @id_vanzare
      AND P.tip_scadere = 'bucata';

    -- 4. PAHAR: scade 0.2 dintr-o sticla per pahar vandut
    UPDATE S
    SET S.cantitate_disponibila = S.cantitate_disponibila
        - (0.2 * DV.cantitate)
    FROM Stocuri S
    INNER JOIN Produs_Ingrediente PI ON S.id_ingredient = PI.id_ingredient
    INNER JOIN Detalii_Vanzari DV   ON PI.id_produs = DV.id_produs
    INNER JOIN Produse P            ON DV.id_produs = P.id
    WHERE DV.id_vanzare = @id_vanzare
      AND P.tip_scadere = 'pahar';
END;
GO

PRINT 'Retete bauturi si stored procedure actualizate cu succes!';
GO



USE MojitoDB;

-- Verificam ce produse europene au putine ingrediente
SELECT P.id, P.nume, COUNT(PI.id_ingredient) AS nr_ingrediente
FROM Produse P
LEFT JOIN Produs_Ingrediente PI ON P.id = PI.id_produs
WHERE P.id_categorie = 1
GROUP BY P.id, P.nume
ORDER BY nr_ingrediente ASC;
GOUSE MojitoDB;

-- Fix 98: Mic dejun englezesc
DELETE FROM Produs_Ingrediente WHERE id_produs = 98;
INSERT INTO Produs_Ingrediente VALUES
(98,58,100),(98,91,150),(98,92,50),(98,93,40),(98,94,60),
(98,96,160),(98,64,2),(98,65,1),(98,67,15),(98,87,2),(98,88,2),(98,89,2);

-- Fix 101: Oua pocheat cu somon si icre rosii
DELETE FROM Produs_Ingrediente WHERE id_produs = 101;
INSERT INTO Produs_Ingrediente VALUES
(101,100,60),(101,101,25),(101,102,10),(101,112,110),
(101,103,25),(101,114,10),(101,58,100);

-- Fix 103: Fritto misto
DELETE FROM Produs_Ingrediente WHERE id_produs = 103;
INSERT INTO Produs_Ingrediente VALUES
(103,154,165),(103,126,40),(103,108,80),(103,109,120),
(103,62,20),(103,64,2),(103,65,1),(103,110,50),(103,111,25);

-- Fix 108: Crunch Set
DELETE FROM Produs_Ingrediente WHERE id_produs = 108;
INSERT INTO Produs_Ingrediente VALUES
(108,109,120),(108,97,130),(108,123,130),(108,110,100);

-- Fix 123: Medalion de vita
DELETE FROM Produs_Ingrediente WHERE id_produs = 123;
INSERT INTO Produs_Ingrediente VALUES
(123,146,110),(123,60,10),(123,61,10),(123,145,125),
(123,67,10),(123,65,3),(123,147,40),(123,95,15);
GO

PRINT 'Fix-uri aplicate!';
GO

USE MojitoDB;

DELETE FROM Produs_Ingrediente WHERE id_produs = 98;
INSERT INTO Produs_Ingrediente VALUES
(98,58,100),(98,91,150),(98,92,50),(98,93,40),(98,94,60),
(98,96,160),(98,64,2),(98,65,1),(98,67,15),(98,87,2),(98,88,2),(98,89,2);

DELETE FROM Produs_Ingrediente WHERE id_produs = 101;
INSERT INTO Produs_Ingrediente VALUES
(101,100,60),(101,101,25),(101,102,10),(101,112,110),
(101,103,25),(101,114,10),(101,58,100);

DELETE FROM Produs_Ingrediente WHERE id_produs = 103;
INSERT INTO Produs_Ingrediente VALUES
(103,154,165),(103,126,40),(103,108,80),(103,109,120),
(103,62,20),(103,64,2),(103,65,1),(103,110,50),(103,111,25);

DELETE FROM Produs_Ingrediente WHERE id_produs = 108;
INSERT INTO Produs_Ingrediente VALUES
(108,109,120),(108,97,130),(108,123,130),(108,110,100);

DELETE FROM Produs_Ingrediente WHERE id_produs = 123;
INSERT INTO Produs_Ingrediente VALUES
(123,146,110),(123,60,10),(123,61,10),(123,145,125),
(123,67,10),(123,65,3),(123,147,40),(123,95,15);
GO


USE MojitoDB;

-- ============================================================
-- INGREDIENTE NOI pentru salate, supe, paste
-- ============================================================
INSERT INTO Ingrediente (nume, unitate_masura) VALUES
('Baby octopus',                'g'),   -- 338
('Baby calamar',                'g'),   -- 339
('Ulei de usturoi',             'g'),   -- 340
('Otet balsamic dressing',      'g'),   -- 341
('Chips de busuioc',            'g'),   -- 342
('Seminte de dovleac',          'g'),   -- 343
('Ceapa chivas',                'g'),   -- 344
('Salata iceberg PF',           'g'),   -- 345
('Frunze de salata',            'g'),   -- 346
('Sos Caesar',                  'g'),   -- 347
('Crutoane',                    'g'),   -- 348
('Pui file panat PF',           'g'),   -- 349
('Creveti fara cap',            'g'),   -- 350
('Telina tulpina',              'g'),   -- 351
('Mar verde',                   'g'),   -- 352
('Zucchini',                    'g'),   -- 353
('Microverdeata',               'g'),   -- 354
('Masline gratar',              'g'),   -- 355
('Sos pesto',                   'g'),   -- 356
('Capere',                      'g'),   -- 357
('Branza Feta',                 'g'),   -- 358
('Oregano',                     'g'),   -- 359
('Nuci de pin',                 'g'),   -- 360
('Ulei verde',                  'g'),   -- 361
('Ardei california rosu',       'g'),   -- 362
('Ardei california galben',     'g'),   -- 363
('Masline negre',               'g'),   -- 364
('Batata coapta',               'g'),   -- 365
('Gorgonzola',                  'g'),   -- 366
('Quinoa PF',                   'g'),   -- 367
('Chips batata',                'g'),   -- 368
('Rosii proaspete',             'g'),   -- 369
('Bors rosu PF',                'g'),   -- 370
('Slanina',                     'g'),   -- 371
('Coaste de porc PF',           'g'),   -- 372
('Zama PF',                     'g'),   -- 373
('Pulpa de pui fiarta',         'g'),   -- 374
('Taitei PF',                   'g'),   -- 375
('Supa crema dovleac PF',       'g'),   -- 376
('Burrata',                     'g'),   -- 377
('Seminte de floarea soarelui2','g'),   -- 378
('Supa crema morcov PF',        'g'),   -- 379
('Pamant masline',              'g'),   -- 380
('Solyanka PF',                 'g'),   -- 381
('Supa crema spanac PF',        'g'),   -- 382
('Branza crema',                'g'),   -- 383
('Paine borodino',              'g'),   -- 384
('Paste rigatoni PF',           'g'),   -- 385
('Jalapeno marinat',            'g'),   -- 386
('Sos tomat PF',                'g'),   -- 387
('Arahide',                     'g'),   -- 388
('Paste spaghetti PF',          'g'),   -- 389
('Frisca lichida',              'g'),   -- 390
('Galbenus de ou',              'g'),   -- 391
('Paste rigatoni puttanesca PF','g'),   -- 392
('Anșoa',                       'g'),   -- 393
('Sos Pillati PF',              'g'),   -- 394
('Paste fettuccine PF',         'g'),   -- 395
('Branza dorblu',               'g'),   -- 396
('Branza brie',                 'g'),   -- 397
('Bisc de creveti PF',          'g'),   -- 398
('Piure morcov PF',             'g'),   -- 399
('Somon obrezki PF',            'g'),   -- 400
('Paste soba PF',               'g'),   -- 401
('Fasole pastai',               'g'),   -- 402
('Ciuperci lemn marinate',      'g'),   -- 403
('Sos wok PF',                  'g'),   -- 404
('Sos stridii',                 'g'),   -- 405
('Paste udon PF',               'g'),   -- 406
('Creveti in aluat PF',         'g'),   -- 407
('Fulgi de ton',                'g'),   -- 408
('Orez pentru risotto PF',      'g'),   -- 409
('Anchoa',                      'g');   -- 410
GO

-- Stocuri initiale pentru ingrediente noi
INSERT INTO Stocuri (id_ingredient, cantitate_disponibila, cantitate_minima)
SELECT id, 3000, 300 FROM Ingrediente WHERE id BETWEEN 338 AND 410;
GO

-- ============================================================
-- PRODUSE NOI: Salate, Supe, Paste
-- ============================================================
INSERT INTO Produse (nume, id_categorie, pret, gramaj, tip_scadere) VALUES
-- SALATE (cat 1, 150-220 MDL)
('Salata Mojito cu fructe de mare',         1, 210.00, '310g', 'ingrediente'),
('Salata Caesar cu pui',                    1, 165.00, '290g', 'ingrediente'),
('Salata Caesar cu creveti',                1, 185.00, '310g', 'ingrediente'),
('Buddha Bowl',                             1, 170.00, '355g', 'ingrediente'),
('Salata cu fructe de mare, quinoa si vinete',1,195.00,'310g', 'ingrediente'),
('Salata cu branza Feta si capere',         1, 155.00, '275g', 'ingrediente'),
('Salata cu batata caramelizata',           1, 150.00, '315g', 'ingrediente'),
-- SUPE (cat 1, 100-165 MDL)
('Bors rosu cu costita',                    1, 120.00, '468g', 'ingrediente'),
('Zama',                                    1, 110.00, '438g', 'ingrediente'),
('Crema de dovleac cu creveti si burrata',  1, 155.00, '381g', 'ingrediente'),
('Crema de morcov cu fructe de mare',       1, 145.00, '341g', 'ingrediente'),
('Solyanka',                                1, 130.00, '398g', 'ingrediente'),
('Crema de spanac cu creveti si icre rosii',1, 150.00, '378g', 'ingrediente'),
-- PASTE (cat 1, 150-220 MDL)
('Rigatoni Arrabbiata cu fructe de mare',   1, 210.00, '470g', 'ingrediente'),
('Spaghetti Carbonara',                     1, 165.00, '306g', 'ingrediente'),
('Rigatoni Puttanesca cu creveti',          1, 195.00, '475g', 'ingrediente'),
('Fettuccine 4 Brânzeturi',                 1, 170.00, '268g', 'ingrediente'),
('Spaghetti cu fructe de mare in bisc',     1, 215.00, '528g', 'ingrediente'),
('Risotto cu fructe de mare',               1, 220.00, '507g', 'ingrediente'),
('Fettuccine cu somon',                     1, 200.00, '352g', 'ingrediente'),
('Soba cu snitel de pui',                   1, 175.00, '360g', 'ingrediente'),
('Udon cu creveti crunch',                  1, 185.00, '355g', 'ingrediente');
GO

-- Verificare ID-uri
SELECT id, nume FROM Produse 
WHERE id_categorie = 1 AND id > 126
ORDER BY id;
GO


USE MojitoDB;

-- ============================================================
-- RETETE SALATE, SUPE, PASTE
-- ============================================================

-- 313: Salata Mojito cu fructe de mare
INSERT INTO Produs_Ingrediente VALUES
(313,338,40),(313,339,40),(313,108,40),(313,67,5),(313,69,5),
(313,340,5),(313,64,2),(313,65,1),(313,102,30),(313,24,70),
(313,53,45),(313,16,35),(313,344,1),(313,29,2),(313,341,20),
(313,342,1),(313,343,2),(313,111,15);

-- 314: Salata Caesar cu pui
INSERT INTO Produs_Ingrediente VALUES
(314,345,60),(314,346,40),(314,347,40),(314,53,60),
(314,348,20),(314,349,110),(314,132,10);

-- 315: Salata Caesar cu creveti
INSERT INTO Produs_Ingrediente VALUES
(315,345,60),(315,346,40),(315,347,40),(315,53,60),
(315,348,20),(315,350,65),(315,110,15),(315,132,10);

-- 316: Buddha Bowl
INSERT INTO Produs_Ingrediente VALUES
(316,102,30),(316,16,40),(316,138,30),(316,67,5),(316,69,5),
(316,24,65),(316,351,10),(316,352,15),(316,126,50),(316,64,2),
(316,106,1),(316,107,1),(316,353,40),(316,51,20),(316,344,2),
(316,341,25),(316,343,4),(316,354,1),(316,380,1),(316,111,25);

-- 317: Salata cu fructe de mare, quinoa si vinete
INSERT INTO Produs_Ingrediente VALUES
(317,338,35),(317,339,35),(317,85,40),(317,64,3),(317,369,85),
(317,368,10),(317,107,2),(317,115,5),(317,22,10),(317,68,15),
(317,110,5),(317,102,30),(317,367,35),(317,111,15);

-- 318: Salata cu branza Feta si capere
INSERT INTO Produs_Ingrediente VALUES
(318,53,90),(318,16,40),(318,355,20),(318,68,10),(318,64,2),
(318,65,1),(318,59,20),(318,356,10),(318,105,2),(318,71,2),
(318,357,6),(318,357,10),(318,358,60),(318,359,1),(318,344,1),
(318,360,2),(318,87,2),(318,361,10);

-- 319: Salata cu batata caramelizata
INSERT INTO Produs_Ingrediente VALUES
(319,16,40),(319,369,78),(319,362,56),(319,364,20),(319,355,20),
(319,365,50),(319,63,5),(319,68,5),(319,358,40),(319,64,2),
(319,65,1),(319,344,1),(319,89,2),(319,87,2),(319,359,1),(319,361,5);

-- 320: Bors rosu cu costita
INSERT INTO Produs_Ingrediente VALUES
(320,370,350),(320,371,30),(320,89,3),(320,372,65),(320,96,20);

-- 321: Zama
INSERT INTO Produs_Ingrediente VALUES
(321,373,350),(321,374,55),(321,375,30),(321,89,3);

-- 322: Crema de dovleac cu creveti si burrata
INSERT INTO Produs_Ingrediente VALUES
(322,376,250),(322,108,55),(322,130,50),(322,377,15),
(322,343,3),(322,378,2),(322,360,2),(322,135,2),(322,361,2),(322,64,2);

-- 323: Crema de morcov cu fructe de mare
INSERT INTO Produs_Ingrediente VALUES
(323,379,250),(323,24,20),(323,343,5),(323,361,3),
(323,338,30),(323,339,30),(323,380,1),(323,135,1),(323,354,1);

-- 324: Solyanka
INSERT INTO Produs_Ingrediente VALUES
(324,381,350),(324,111,25),(324,364,20),(324,89,3);

-- 325: Crema de spanac cu creveti si icre rosii
INSERT INTO Produs_Ingrediente VALUES
(325,382,250),(325,108,55),(325,114,5),(325,383,15),
(325,384,50),(325,361,1),(325,64,2);

-- 326: Rigatoni Arrabbiata cu fructe de mare
INSERT INTO Produs_Ingrediente VALUES
(326,385,160),(326,386,10),(326,340,5),(326,387,120),
(326,338,40),(326,339,40),(326,108,40),(326,61,10),
(326,88,4),(326,110,20),(326,388,10),(326,132,6),(326,342,2);

-- 327: Spaghetti Carbonara
INSERT INTO Produs_Ingrediente VALUES
(327,389,120),(327,94,55),(327,390,100),(327,132,14),
(327,64,2),(327,391,15),(327,68,1);

-- 328: Rigatoni Puttanesca cu creveti
INSERT INTO Produs_Ingrediente VALUES
(328,392,160),(328,108,85),(328,340,5),(328,53,65),
(328,364,15),(328,355,15),(328,393,5),(328,61,10),
(328,88,2),(328,132,10),(328,394,100),(328,115,6),
(328,360,2),(328,361,2);

-- 329: Fettuccine 4 Branzeturi
INSERT INTO Produs_Ingrediente VALUES
(329,395,120),(329,390,95),(329,132,15),(329,64,2),
(329,65,1),(329,101,15),(329,396,15),(329,397,20),(329,366,20);

-- 330: Spaghetti cu fructe de mare in bisc
INSERT INTO Produs_Ingrediente VALUES
(330,389,120),(330,338,45),(330,339,45),(330,108,45),
(330,387,80),(330,398,50),(330,70,5),(330,61,5),
(330,89,3),(330,132,10),(330,88,2),(330,354,1),(330,380,1);

-- 331: Risotto cu fructe de mare
INSERT INTO Produs_Ingrediente VALUES
(331,409,120),(331,338,45),(331,339,45),(331,108,45),
(331,390,70),(331,398,50),(331,61,15),(331,132,15),
(331,399,50),(331,68,1),(331,354,1);

-- 332: Fettuccine cu somon
INSERT INTO Produs_Ingrediente VALUES
(332,395,120),(332,400,85),(332,390,95),(332,366,30),
(332,64,2),(332,65,1),(332,68,2),(332,132,4),
(332,114,5),(332,342,2),(332,380,1),(332,67,10),(332,340,5),(332,69,15);

-- 333: Soba cu snitel de pui
INSERT INTO Produs_Ingrediente VALUES
(333,401,120),(333,349,90),(333,51,9),(333,402,20),
(333,363,20),(333,362,20),(333,403,20),(333,404,75),
(333,405,20),(333,118,10),(333,29,3),(333,380,1),
(333,155,10),(333,344,1),(333,404,10);

-- 334: Udon cu creveti crunch
INSERT INTO Produs_Ingrediente VALUES
(334,406,120),(334,407,70),(334,51,9),(334,402,20),
(334,363,20),(334,362,20),(334,403,20),(334,404,75),
(334,405,20),(334,110,6),(334,408,1),(334,29,3),
(334,380,1),(334,344,1),(334,404,10);
GO

PRINT 'Retete salate, supe si paste inserate cu succes!';
GO