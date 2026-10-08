/* =====================================================================
   TryOn: киімді 3D манекенге кигізіп көруге болатын интернет-дүкеннің дерекқоры
   СУБД: Microsoft SQL Server 2016+ (SSMS немесе Azure Data Studio).
   Іске қосу реті: 01_schema.sql -> 02_seed.sql -> 03_queries.sql -> 04_tests.sql -> 05_update_delete.sql

   14 кесте = 14 класс (Class Diagram-мен сәйкес, әр FOREIGN KEY = бір байланыс):
     roles, users ............ Role, User              body_profiles ... BodyProfile
     addresses ............... Address                 categories ...... Category
     garment_types, fit_rules  GarmentType, FitRule     products ........ Product
     product_sizes ........... ProductSize             cart_items ...... CartItem
     orders, order_items ..... Order, OrderItem         payments ........ Payment
     return_requests ......... ReturnRequest

   Негізгі принциптер:
   1) Ақша бүтін теңгемен (KZT). 2) Тапсырыс жолында атау мен баға «снимок» ретінде сақталады.
   3) Отыру шектері fit_rules кестесінде, киім түріне (garment_types) байланған.
   4) Бизнес-ережелер триггермен қорғалады: қате болса, ROLLBACK және THROW.
   ===================================================================== */
IF DB_ID(N'TryOn') IS NULL CREATE DATABASE TryOn;
GO
USE TryOn;
GO

-- ---------------------------------------------------------------------
-- 1. АНЫҚТАМАЛЫҚТАР
-- ---------------------------------------------------------------------
CREATE TABLE dbo.roles (
  id   INT NOT NULL PRIMARY KEY,
  code NVARCHAR(20) NOT NULL UNIQUE CHECK (code IN ('client','seller','manager','admin')),
  name NVARCHAR(50) NOT NULL
);

CREATE TABLE dbo.garment_types (          -- киім түрі (GarmentType enumeration)
  code NVARCHAR(20) NOT NULL PRIMARY KEY,
  name NVARCHAR(50) NOT NULL,
  slot NVARCHAR(10) NOT NULL CHECK (slot IN ('top','bottom','shoes'))
);

CREATE TABLE dbo.fit_rules (              -- FitRule: әр киім түрі мен аймаққа бір отыру ережесі
  id           INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
  garment_type NVARCHAR(20) NOT NULL REFERENCES dbo.garment_types(code),
  zone         NVARCHAR(10) NOT NULL CHECK (zone IN ('chest','hem','waist','hip','thigh')),
  tight_below  DECIMAL(4,1) NOT NULL,     -- киім − дене айырмасы осыдан аз болса: «қысады»
  loose_above  DECIMAL(4,1) NOT NULL,     -- осыдан көп болса: «бос»
  CONSTRAINT uq_fit_rule UNIQUE (garment_type, zone),
  CHECK (tight_below < loose_above)
);

-- ---------------------------------------------------------------------
-- 2. ПАЙДАЛАНУШЫЛАР
-- ---------------------------------------------------------------------
CREATE TABLE dbo.users (                  -- User: рөл role_id арқылы (Role)
  id            INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
  email         NVARCHAR(255) NOT NULL UNIQUE,
  password_hash NVARCHAR(255) NOT NULL,
  full_name     NVARCHAR(150) NOT NULL,
  phone         NVARCHAR(30) NULL,
  role_id       INT NOT NULL REFERENCES dbo.roles(id),
  shop_name     NVARCHAR(150) NULL,       -- тек сатушыға (User.shopName)
  is_active     BIT NOT NULL DEFAULT 1,   -- пайдаланушыны жоймаймыз, өшіреміз
  created_at    DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.body_profiles (          -- BodyProfile: клиентпен 1:1
  user_id   INT NOT NULL PRIMARY KEY REFERENCES dbo.users(id) ON DELETE CASCADE,
  sex       CHAR(1) NOT NULL DEFAULT 'n' CHECK (sex IN ('m','f','n')),
  height_cm INT NOT NULL CHECK (height_cm BETWEEN 120 AND 230),
  weight_kg DECIMAL(5,1) NOT NULL CHECK (weight_kg BETWEEN 30 AND 250),
  chest_cm  DECIMAL(5,1) NOT NULL CHECK (chest_cm BETWEEN 50 AND 200),
  waist_cm  DECIMAL(5,1) NOT NULL CHECK (waist_cm BETWEEN 40 AND 200),
  hip_cm    DECIMAL(5,1) NOT NULL CHECK (hip_cm BETWEEN 60 AND 200),
  is_manual BIT NOT NULL DEFAULT 0        -- 1: клиент өлшемдерді өзі енгізді, 0: бой мен салмақтан бағаланған
);

CREATE TABLE dbo.addresses (              -- Address: клиентпен 1:N
  id              INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
  user_id         INT NOT NULL REFERENCES dbo.users(id) ON DELETE CASCADE,
  city            NVARCHAR(100) NOT NULL,
  street          NVARCHAR(150) NOT NULL,
  house           NVARCHAR(20) NOT NULL,
  apartment       NVARCHAR(20) NULL,
  recipient_phone NVARCHAR(30) NOT NULL,
  is_default      BIT NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX ux_addresses_one_default ON dbo.addresses(user_id) WHERE is_default = 1;

-- ---------------------------------------------------------------------
-- 3. КАТАЛОГ
-- ---------------------------------------------------------------------
CREATE TABLE dbo.categories (
  id        INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
  name      NVARCHAR(100) NOT NULL,
  slug      NVARCHAR(100) NOT NULL UNIQUE,
  parent_id INT NULL REFERENCES dbo.categories(id)
);

CREATE TABLE dbo.products (
  id           INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
  seller_id    INT NOT NULL REFERENCES dbo.users(id),
  category_id  INT NOT NULL REFERENCES dbo.categories(id),
  garment_type NVARCHAR(20) NOT NULL REFERENCES dbo.garment_types(code),
  name         NVARCHAR(200) NOT NULL,
  description  NVARCHAR(1000) NULL,
  price        INT NOT NULL CHECK (price > 0),
  color_hex    CHAR(7) NOT NULL DEFAULT '#cccccc'
               CHECK (color_hex LIKE '#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]'),
  pattern      NVARCHAR(10) NOT NULL DEFAULT 'solid' CHECK (pattern IN ('solid','stripe','check','dot')),
  print_kind   NVARCHAR(10) NULL CHECK (print_kind IN ('logo','star','image')),
  image_path   NVARCHAR(300) NULL,
  is_active    BIT NOT NULL DEFAULT 1
);

CREATE TABLE dbo.product_sizes (          -- ProductSize: өлшем кестесінің жолы + қалдық
  id         INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
  product_id INT NOT NULL REFERENCES dbo.products(id) ON DELETE CASCADE,
  size_label NVARCHAR(10) NOT NULL CHECK (size_label IN ('XS','S','M','L','XL','XXL','38','39','40','41','42','43','44','45','46')),
  sku        NVARCHAR(40) NOT NULL UNIQUE,
  chest_cm   DECIMAL(5,1) NULL CHECK (chest_cm > 0),   -- топ: кеуде, етек
  hem_cm     DECIMAL(5,1) NULL CHECK (hem_cm   > 0),
  waist_cm   DECIMAL(5,1) NULL CHECK (waist_cm > 0),   -- төменгі киім: бел, жамбас, сан
  hip_cm     DECIMAL(5,1) NULL CHECK (hip_cm   > 0),
  thigh_cm   DECIMAL(5,1) NULL CHECK (thigh_cm > 0),
  length_cm  DECIMAL(5,1) NULL CHECK (length_cm > 0),  -- аяқ киім: табан ұзындығы
  stock_qty  INT NOT NULL DEFAULT 0 CHECK (stock_qty >= 0),
  CONSTRAINT uq_product_size UNIQUE (product_id, size_label)
);

-- ---------------------------------------------------------------------
-- 4. САТЫП АЛУ
-- ---------------------------------------------------------------------
CREATE TABLE dbo.cart_items (             -- CartItem
  user_id         INT NOT NULL REFERENCES dbo.users(id) ON DELETE CASCADE,
  product_size_id INT NOT NULL REFERENCES dbo.product_sizes(id) ON DELETE CASCADE,
  qty             INT NOT NULL CHECK (qty > 0),
  PRIMARY KEY (user_id, product_size_id)
);

CREATE TABLE dbo.orders (
  id           INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
  customer_id  INT NOT NULL REFERENCES dbo.users(id),
  address_id   INT NOT NULL REFERENCES dbo.addresses(id),
  manager_id   INT NULL REFERENCES dbo.users(id),
  status       NVARCHAR(10) NOT NULL DEFAULT 'new' CHECK (status IN ('new','paid','packed','shipped','delivered','cancelled')),
  total_amount INT NOT NULL DEFAULT 0 CHECK (total_amount >= 0),   -- order_items триггерімен есептеледі
  created_at   DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);

CREATE TABLE dbo.order_items (
  id              INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
  order_id        INT NOT NULL REFERENCES dbo.orders(id) ON DELETE CASCADE,
  product_size_id INT NOT NULL REFERENCES dbo.product_sizes(id),
  product_name    NVARCHAR(200) NOT NULL,                          -- снимок
  unit_price      INT NOT NULL CHECK (unit_price > 0),             -- снимок
  qty             INT NOT NULL CHECK (qty > 0),
  CONSTRAINT uq_order_item UNIQUE (order_id, product_size_id)
);

CREATE TABLE dbo.payments (
  id       INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
  order_id INT NOT NULL REFERENCES dbo.orders(id),
  amount   INT NOT NULL CHECK (amount > 0),
  method   NVARCHAR(10) NOT NULL CHECK (method IN ('card','kaspi','cash')),
  status   NVARCHAR(10) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','paid','failed')),
  paid_at  DATETIME2(0) NULL
);

CREATE TABLE dbo.return_requests (
  id            INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
  order_item_id INT NOT NULL REFERENCES dbo.order_items(id),
  qty           INT NOT NULL CHECK (qty > 0),
  reason        NVARCHAR(20) NOT NULL CHECK (reason IN ('too_small','too_big','defect','not_as_shown','changed_mind')),
  comment       NVARCHAR(500) NULL,
  status        NVARCHAR(10) NOT NULL DEFAULT 'requested' CHECK (status IN ('requested','approved','rejected','refunded')),
  handled_by    INT NULL REFERENCES dbo.users(id),
  refund_amount INT NULL CHECK (refund_amount > 0),
  created_at    DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

-- ---------------------------------------------------------------------
-- 5. ИНДЕКСТЕР
-- ---------------------------------------------------------------------
CREATE INDEX ix_users_role      ON dbo.users(role_id);
CREATE INDEX ix_products_seller ON dbo.products(seller_id);
CREATE INDEX ix_products_cat    ON dbo.products(category_id);
CREATE INDEX ix_sizes_product   ON dbo.product_sizes(product_id);
CREATE INDEX ix_orders_customer ON dbo.orders(customer_id);
CREATE INDEX ix_items_order     ON dbo.order_items(order_id);
CREATE INDEX ix_items_size      ON dbo.order_items(product_size_id);
CREATE INDEX ix_payments_order  ON dbo.payments(order_id);
CREATE INDEX ix_returns_item    ON dbo.return_requests(order_item_id);
GO

-- ---------------------------------------------------------------------
-- 6. ТРИГГЕРЛЕР (бизнес-ережелер). Қате болса: ROLLBACK + THROW
-- ---------------------------------------------------------------------
-- 6.1 Рөл шектеулері
CREATE TRIGGER dbo.trg_body_profile_role ON dbo.body_profiles AFTER INSERT, UPDATE AS
BEGIN
  SET NOCOUNT ON;
  IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.users u ON u.id = i.user_id JOIN dbo.roles r ON r.id = u.role_id WHERE r.code <> 'client')
  BEGIN
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50002, N'body_profiles: пайдаланушының рөлі «клиент» емес', 1;
  END
END
GO

CREATE TRIGGER dbo.trg_products_seller ON dbo.products AFTER INSERT, UPDATE AS
BEGIN
  SET NOCOUNT ON;
  IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.users u ON u.id = i.seller_id JOIN dbo.roles r ON r.id = u.role_id WHERE r.code <> 'seller')
  BEGIN
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50003, N'products: seller_id сатушыға тиесілі болуы керек', 1;
  END
END
GO

-- 6.2 Өлшем кестесі: киім түріне қарай міндетті өлшемдер және өлшем белгісінің түрі
CREATE TRIGGER dbo.trg_sizes_validate ON dbo.product_sizes AFTER INSERT, UPDATE AS
BEGIN
  SET NOCOUNT ON;
  IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.products p ON p.id = i.product_id JOIN dbo.garment_types gt ON gt.code = p.garment_type
             WHERE gt.slot = 'top' AND (i.chest_cm IS NULL OR i.hem_cm IS NULL))
  BEGIN
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50010, N'Топ үшін кеуде (chest_cm) және етек (hem_cm) міндетті', 1;
  END
  IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.products p ON p.id = i.product_id JOIN dbo.garment_types gt ON gt.code = p.garment_type
             WHERE gt.slot = 'bottom' AND (i.waist_cm IS NULL OR i.hip_cm IS NULL OR i.thigh_cm IS NULL))
  BEGIN
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50011, N'Төменгі киім үшін бел, жамбас және сан өлшемдері міндетті', 1;
  END
  IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.products p ON p.id = i.product_id JOIN dbo.garment_types gt ON gt.code = p.garment_type
             WHERE (gt.slot = 'shoes' AND i.size_label NOT LIKE '[0-9]%') OR (gt.slot <> 'shoes' AND i.size_label LIKE '[0-9]%'))
  BEGIN
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50012, N'Өлшем белгісі киім түріне сәйкес емес: аяқ киімге 38–46, киімге XS–XXL', 1;
  END
END
GO

-- 6.3 Тапсырыс жолы: қалдықты тексеру, азайту, соманы есептеу
CREATE TRIGGER dbo.trg_order_items_ins ON dbo.order_items AFTER INSERT AS
BEGIN
  SET NOCOUNT ON;
  IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.orders o ON o.id = i.order_id WHERE o.status <> 'new')
  BEGIN
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50020, N'Тапсырыс жолын тек «new» мәртебесіндегі тапсырысқа қосуға болады', 1;
  END
  IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.product_sizes ps ON ps.id = i.product_size_id JOIN dbo.products p ON p.id = ps.product_id WHERE p.is_active = 0)
  BEGIN
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50021, N'Тауар сатылымнан алынған', 1;
  END
  IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.product_sizes ps ON ps.id = i.product_size_id WHERE ps.stock_qty < i.qty)
  BEGIN
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50022, N'Қоймада қалдық жеткіліксіз', 1;
  END
  UPDATE ps SET stock_qty = ps.stock_qty - x.q
  FROM dbo.product_sizes ps JOIN (SELECT product_size_id, SUM(qty) AS q FROM inserted GROUP BY product_size_id) x ON x.product_size_id = ps.id;
  UPDATE o SET total_amount = o.total_amount + x.s
  FROM dbo.orders o JOIN (SELECT order_id, SUM(qty * unit_price) AS s FROM inserted GROUP BY order_id) x ON x.order_id = o.id;
END
GO

-- 6.4 Тапсырыс: клиент рөлі, мәртебе ауысулары, бас тартқанда қалдық қайтады, жоюға тыйым
CREATE TRIGGER dbo.trg_orders_ins ON dbo.orders AFTER INSERT AS
BEGIN
  SET NOCOUNT ON;
  IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.users u ON u.id = i.customer_id JOIN dbo.roles r ON r.id = u.role_id WHERE r.code <> 'client')
  BEGIN
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50004, N'orders: тапсырыс тек клиентке жасалады', 1;
  END
END
GO

CREATE TRIGGER dbo.trg_orders_upd ON dbo.orders AFTER UPDATE AS
BEGIN
  SET NOCOUNT ON;
  IF NOT UPDATE(status) RETURN;
  IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.id = i.id
             WHERE i.status <> d.status
               AND NOT ((d.status = 'new'     AND i.status IN ('paid','cancelled'))
                     OR (d.status = 'paid'    AND i.status IN ('packed','cancelled'))
                     OR (d.status = 'packed'  AND i.status IN ('shipped','cancelled'))
                     OR (d.status = 'shipped' AND i.status = 'delivered')))
  BEGIN
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50030, N'Рұқсат етілмеген мәртебе ауысуы', 1;
  END
  UPDATE ps SET stock_qty = ps.stock_qty + x.q
  FROM dbo.product_sizes ps
  JOIN (SELECT oi.product_size_id AS psid, SUM(oi.qty) AS q
        FROM inserted i JOIN deleted d ON d.id = i.id JOIN dbo.order_items oi ON oi.order_id = i.id
        WHERE i.status = 'cancelled' AND d.status <> 'cancelled' GROUP BY oi.product_size_id) x ON x.psid = ps.id;
END
GO

CREATE TRIGGER dbo.trg_orders_no_delete ON dbo.orders AFTER DELETE AS
BEGIN
  SET NOCOUNT ON;
  IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
  THROW 50024, N'Тапсырысты жоюға болмайды: «cancelled» мәртебесін қойыңыз', 1;
END
GO

-- 6.5 Төлем: толық төленсе, тапсырыс «paid» болады
CREATE TRIGGER dbo.trg_payments_paid ON dbo.payments AFTER INSERT, UPDATE AS
BEGIN
  SET NOCOUNT ON;
  UPDATE o SET status = 'paid'
  FROM dbo.orders o
  WHERE o.status = 'new'
    AND o.id IN (SELECT order_id FROM inserted WHERE status = 'paid')
    AND (SELECT ISNULL(SUM(p.amount), 0) FROM dbo.payments p WHERE p.order_id = o.id AND p.status = 'paid') >= o.total_amount;
END
GO

-- 6.6 Қайтару
CREATE TRIGGER dbo.trg_returns_ins ON dbo.return_requests AFTER INSERT AS
BEGIN
  SET NOCOUNT ON;
  IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.order_items oi ON oi.id = i.order_item_id JOIN dbo.orders o ON o.id = oi.order_id WHERE o.status <> 'delivered')
  BEGIN
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50040, N'Қайтаруды тек жеткізілген («delivered») тапсырыс бойынша жасауға болады', 1;
  END
  IF EXISTS (SELECT 1 FROM inserted i JOIN dbo.order_items oi ON oi.id = i.order_item_id
             WHERE i.qty > oi.qty - ISNULL((SELECT SUM(rr.qty) FROM dbo.return_requests rr
                                            WHERE rr.order_item_id = i.order_item_id AND rr.status <> 'rejected' AND rr.id <> i.id), 0))
  BEGIN
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50041, N'Қайтару саны сатып алынған саннан артық', 1;
  END
END
GO

CREATE TRIGGER dbo.trg_returns_upd ON dbo.return_requests AFTER UPDATE AS
BEGIN
  SET NOCOUNT ON;
  IF NOT UPDATE(status) RETURN;
  IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.id = i.id
             WHERE i.status <> d.status
               AND NOT ((d.status = 'requested' AND i.status IN ('approved','rejected')) OR (d.status = 'approved' AND i.status = 'refunded')))
  BEGIN
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW 50042, N'Қайтару мәртебесінің рұқсат етілмеген ауысуы', 1;
  END
  -- ақаулы тауар қоймаға қайтпайды, қалғандары қайтады
  UPDATE ps SET stock_qty = ps.stock_qty + x.q
  FROM dbo.product_sizes ps
  JOIN (SELECT oi.product_size_id AS psid, SUM(i.qty) AS q
        FROM inserted i JOIN deleted d ON d.id = i.id JOIN dbo.order_items oi ON oi.id = i.order_item_id
        WHERE i.status = 'refunded' AND d.status <> 'refunded' AND i.reason <> 'defect' GROUP BY oi.product_size_id) x ON x.psid = ps.id;
END
GO

-- ---------------------------------------------------------------------
-- 7. VIEW: отыру логикасы (FitRule ережелері бойынша). diff = киім өлшемі − дене өлшемі
-- Ережелер fit_rules кестесінен алынады: киім түрі (garment_type) мен аймақ (zone) бойынша.
-- Сан өлшемі денеден шамамен: жамбас × 0.56
-- ---------------------------------------------------------------------
CREATE VIEW dbo.v_fit_zones AS
WITH base AS (
  SELECT bp.user_id, bp.chest_cm AS b_chest, bp.waist_cm AS b_waist, bp.hip_cm AS b_hip,
         ps.id AS product_size_id, ps.product_id, ps.size_label, p.garment_type, gt.slot,
         CASE ps.size_label WHEN 'XS' THEN 1 WHEN 'S' THEN 2 WHEN 'M' THEN 3 WHEN 'L' THEN 4 WHEN 'XL' THEN 5 WHEN 'XXL' THEN 6 ELSE 99 END AS size_rank,
         ps.chest_cm, ps.hem_cm, ps.waist_cm, ps.hip_cm, ps.thigh_cm
  FROM dbo.body_profiles bp
  CROSS JOIN dbo.product_sizes ps
  JOIN dbo.products p       ON p.id = ps.product_id
  JOIN dbo.garment_types gt ON gt.code = p.garment_type
), z AS (
  SELECT user_id, product_size_id, product_id, size_label, size_rank, garment_type, CAST('chest' AS NVARCHAR(10)) AS zone, b_chest AS body_cm, chest_cm AS garment_cm FROM base WHERE slot = 'top'    AND chest_cm IS NOT NULL
  UNION ALL
  SELECT user_id, product_size_id, product_id, size_label, size_rank, garment_type, 'hem',   b_hip,                       hem_cm   FROM base WHERE slot = 'top'    AND hem_cm   IS NOT NULL
  UNION ALL
  SELECT user_id, product_size_id, product_id, size_label, size_rank, garment_type, 'waist', b_waist,                     waist_cm FROM base WHERE slot = 'bottom' AND waist_cm IS NOT NULL
  UNION ALL
  SELECT user_id, product_size_id, product_id, size_label, size_rank, garment_type, 'hip',   b_hip,                       hip_cm   FROM base WHERE slot = 'bottom' AND hip_cm   IS NOT NULL
  UNION ALL
  SELECT user_id, product_size_id, product_id, size_label, size_rank, garment_type, 'thigh', CAST(ROUND(b_hip * 0.56, 1) AS DECIMAL(6,1)), thigh_cm FROM base WHERE slot = 'bottom' AND thigh_cm IS NOT NULL
)
SELECT z.user_id, z.product_size_id, z.product_id, z.size_label, z.size_rank, z.zone,
       z.body_cm, z.garment_cm,
       CAST(z.garment_cm - z.body_cm AS DECIMAL(6,1)) AS diff_cm,
       r.tight_below, r.loose_above,
       CASE WHEN z.garment_cm - z.body_cm < r.tight_below THEN 'tight'
            WHEN z.garment_cm - z.body_cm > r.loose_above THEN 'loose'
            ELSE 'fit' END AS verdict
FROM z JOIN dbo.fit_rules r ON r.garment_type = z.garment_type AND r.zone = z.zone;
GO

CREATE VIEW dbo.v_size_verdict AS         -- бір өлшемнің жалпы үкімі
SELECT user_id, product_size_id, product_id, size_label, size_rank,
       CASE WHEN SUM(CASE WHEN verdict = 'tight' THEN 1 ELSE 0 END) > 0 THEN 'tight'
            WHEN SUM(CASE WHEN verdict = 'loose' THEN 1 ELSE 0 END) > 0 THEN 'loose'
            ELSE 'fit' END AS verdict
FROM dbo.v_fit_zones
GROUP BY user_id, product_size_id, product_id, size_label, size_rank;
GO

CREATE VIEW dbo.v_recommended_size AS     -- ұсынылатын өлшем: «қысатын» аймағы жоқ және қоймада бар ең кіші өлшем
SELECT x.user_id, x.product_id, x.product_size_id, x.size_label
FROM (
  SELECT v.user_id, v.product_id, v.product_size_id, v.size_label,
         ROW_NUMBER() OVER (PARTITION BY v.user_id, v.product_id ORDER BY v.size_rank) AS rn
  FROM dbo.v_size_verdict v
  JOIN dbo.product_sizes ps ON ps.id = v.product_size_id AND ps.stock_qty > 0
  WHERE v.verdict <> 'tight'
) x
WHERE x.rn = 1;
GO
