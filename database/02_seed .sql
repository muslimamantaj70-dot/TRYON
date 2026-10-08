/* TryOn (SQL Server): бастапқы деректер (INSERT). 01_schema.sql орындалғаннан кейін іске қосыңыз.
   Логика: ешбір сыртқы кілт «қолмен» (нөмірмен) жазылмайды. Әр байланыс табиғи кілт арқылы подзапроспен алынады
   (email, өнім атауы, sku), ал тапсырыс жолының атауы мен бағасы products кестесінен INSERT ... SELECT арқылы көшіріледі. */
USE TryOn;
GO
SET NOCOUNT ON;
GO

-- 1. АНЫҚТАМАЛЫҚТАР
INSERT INTO dbo.roles(id, code, name) VALUES (1,'client',N'Клиент'),(2,'seller',N'Сатушы'),(3,'manager',N'Менеджер'),(4,'admin',N'Әкімші');

INSERT INTO dbo.garment_types(code, name, slot) VALUES
 ('tee',N'Футболка','top'),('sweater',N'Свитер','top'),('shorts',N'Шорты','bottom'),('pants',N'Шалбар','bottom'),('sneakers',N'Кроссовка','shoes');

-- отыру ережелері киім түріне байланған (garment_type → garment_types): свитер еркін киіледі, сондықтан шектері кеңірек
INSERT INTO dbo.fit_rules(garment_type, zone, tight_below, loose_above) VALUES
 ('tee','chest',2,10),    ('tee','hem',2,10),
 ('sweater','chest',2,16),('sweater','hem',2,12),
 ('shorts','waist',2,10), ('shorts','hip',2,10), ('shorts','thigh',1,10),
 ('pants','waist',2,10),  ('pants','hip',2,10),  ('pants','thigh',1,10);

-- 2. САНАТТАР: алдымен ата-санаттар, сосын parent_id подзапроспен
INSERT INTO dbo.categories(name, slug, parent_id) VALUES (N'Жоғарғы киім','tops',NULL),(N'Төменгі киім','bottoms',NULL),(N'Аяқ киім','footwear',NULL);
INSERT INTO dbo.categories(name, slug, parent_id) VALUES
 (N'Футболкалар','t-shirts',(SELECT id FROM dbo.categories WHERE slug='tops')),
 (N'Свитерлер','sweaters',(SELECT id FROM dbo.categories WHERE slug='tops')),
 (N'Шортылар','shorts',(SELECT id FROM dbo.categories WHERE slug='bottoms')),
 (N'Шалбарлар','pants',(SELECT id FROM dbo.categories WHERE slug='bottoms')),
 (N'Кроссовкалар','sneakers',(SELECT id FROM dbo.categories WHERE slug='footwear'));

-- 3. ПАЙДАЛАНУШЫЛАР: role_id рөл кодынан алынады (қолмен нөмір жоқ); shop_name тек сатушыда
INSERT INTO dbo.users(email, password_hash, full_name, phone, role_id, shop_name)
SELECT v.email, 'hash_demo', v.full_name, v.phone, r.id, v.shop_name
FROM (
  SELECT 'admin@tryon.kz' AS email, N'Әкімші TryOn' AS full_name, '+77000000001' AS phone, 'admin' AS role_code, CAST(NULL AS NVARCHAR(150)) AS shop_name
  UNION ALL SELECT 'manager@tryon.kz', N'Асхат Оразов', '+77000000002', 'manager', NULL
  UNION ALL SELECT 'seller1@tryon.kz', N'Нұрлан Әбдіқадыр', '+77000000003', 'seller', N'UrbanWear'
  UNION ALL SELECT 'seller2@tryon.kz', N'Меруерт Сәкенова', '+77000000004', 'seller', N'Basic Studio'
  UNION ALL SELECT 'aigerim@example.com', N'Айгерім Қасымова', '+77010000005', 'client', NULL
  UNION ALL SELECT 'daniyar@example.com', N'Данияр Төлеген', '+77010000006', 'client', NULL
  UNION ALL SELECT 'aliya@example.com', N'Әлия Серікбай', '+77010000007', 'client', NULL
  UNION ALL SELECT 'zhandos@example.com', N'Жандос Мұратов', '+77010000008', 'client', NULL
) v JOIN dbo.roles r ON r.code = v.role_code;

-- клиенттердің дене профилі. is_manual = 0: мәндер жүйенің бағалау формуласымен бой мен салмақтан есептелген; 1: клиент өзі енгізген
INSERT INTO dbo.body_profiles(user_id, sex, height_cm, weight_kg, chest_cm, waist_cm, hip_cm, is_manual) VALUES
 ((SELECT id FROM dbo.users WHERE email = 'aigerim@example.com'), 'f', 165, 58, 86.2, 69.8, 100.2, 0),
 ((SELECT id FROM dbo.users WHERE email = 'daniyar@example.com'), 'm', 182, 95, 111.7, 96.2, 112.6, 0),
 ((SELECT id FROM dbo.users WHERE email = 'aliya@example.com'),   'f', 170, 62, 90.0, 72.0, 98.0, 1),
 ((SELECT id FROM dbo.users WHERE email = 'zhandos@example.com'), 'm', 175, 70, 98.9, 83.8, 101.2, 0);

-- мекенжайлар: әр клиентте бір әдепкі мекенжай
INSERT INTO dbo.addresses(user_id, city, street, house, apartment, recipient_phone, is_default) VALUES
 ((SELECT id FROM dbo.users WHERE email = 'aigerim@example.com'), N'Алматы', N'Абай даңғылы', '10', '25', '+77010000005', 1),
 ((SELECT id FROM dbo.users WHERE email = 'daniyar@example.com'), N'Астана', N'Достық көшесі', '5', NULL, '+77010000006', 1),
 ((SELECT id FROM dbo.users WHERE email = 'aliya@example.com'),   N'Шымкент', N'Тауке хан даңғылы', '42', '7', '+77010000007', 1),
 ((SELECT id FROM dbo.users WHERE email = 'zhandos@example.com'), N'Қарағанды', N'Бұқар жырау даңғылы', '18', '3', '+77010000008', 1);

-- 4. ТАУАРЛАР: seller_id email арқылы, category_id slug арқылы; тауар түрі санатқа сәйкес
INSERT INTO dbo.products(seller_id, category_id, garment_type, name, description, price, color_hex, pattern, print_kind, image_path) VALUES
 ((SELECT id FROM dbo.users WHERE email = 'seller1@tryon.kz'), (SELECT id FROM dbo.categories WHERE slug = 't-shirts'), 'tee', N'Футболка «TryOn» ақ', N'Мақта, түзу пішін, кеудесінде TryOn логотипі', 8900, '#f4f1ea', 'solid', 'logo', 'img/tee_tryon_white.jpg'),
 ((SELECT id FROM dbo.users WHERE email = 'seller1@tryon.kz'), (SELECT id FROM dbo.categories WHERE slug = 't-shirts'), 'tee', N'Футболка «Stripe» көк-ақ', N'Мақта, көлденең жолақ', 9500, '#2f5d8a', 'stripe', NULL, 'img/tee_stripe_blue.jpg'),
 ((SELECT id FROM dbo.users WHERE email = 'seller1@tryon.kz'), (SELECT id FROM dbo.categories WHERE slug = 'sweaters'), 'sweater', N'Свитер «Winter» көк', N'Жылы, манжеттері мен етегі резеңкелі', 19900, '#2f5d8a', 'solid', NULL, 'img/sweater_winter_blue.jpg'),
 ((SELECT id FROM dbo.users WHERE email = 'seller1@tryon.kz'), (SELECT id FROM dbo.categories WHERE slug = 'sweaters'), 'sweater', N'Свитер «Classic» қара', N'Классикалық, жұқа жүн қоспасы', 21900, '#1f2430', 'solid', NULL, 'img/sweater_classic_black.jpg'),
 ((SELECT id FROM dbo.users WHERE email = 'seller1@tryon.kz'), (SELECT id FROM dbo.categories WHERE slug = 'sneakers'), 'sneakers', N'Кроссовка «Runner» ақ', N'Күнделікті жүгіру кроссовкасы', 24900, '#f4f1ea', 'solid', NULL, 'img/sneaker_runner_white.jpg'),
 ((SELECT id FROM dbo.users WHERE email = 'seller2@tryon.kz'), (SELECT id FROM dbo.categories WHERE slug = 'shorts'), 'shorts', N'Шорты «Active» қара', N'Жеңіл, спорттық', 9900, '#1f2430', 'solid', NULL, 'img/shorts_active_black.jpg'),
 ((SELECT id FROM dbo.users WHERE email = 'seller2@tryon.kz'), (SELECT id FROM dbo.categories WHERE slug = 'shorts'), 'shorts', N'Шорты «Casual» хаки', N'Мақта, күнделікті', 10900, '#6b705c', 'solid', NULL, 'img/shorts_casual_khaki.jpg'),
 ((SELECT id FROM dbo.users WHERE email = 'seller2@tryon.kz'), (SELECT id FROM dbo.categories WHERE slug = 'pants'), 'pants', N'Шалбар «Straight» сұр', N'Түзу пішін', 15900, '#8c8c8c', 'solid', NULL, 'img/pants_straight_grey.jpg'),
 ((SELECT id FROM dbo.users WHERE email = 'seller2@tryon.kz'), (SELECT id FROM dbo.categories WHERE slug = 'pants'), 'pants', N'Шалбар «Chino» қоңыр-сары', N'Чино, мақта', 17900, '#c2a878', 'solid', NULL, 'img/pants_chino_tan.jpg'),
 ((SELECT id FROM dbo.users WHERE email = 'seller2@tryon.kz'), (SELECT id FROM dbo.categories WHERE slug = 't-shirts'), 'tee', N'Футболка «Basic» қара', N'Базалық футболка', 7900, '#1f2430', 'solid', NULL, 'img/tee_basic_black.jpg'),
 ((SELECT id FROM dbo.users WHERE email = 'seller2@tryon.kz'), (SELECT id FROM dbo.categories WHERE slug = 'sneakers'), 'sneakers', N'Кроссовка «City» қара', N'Қалаға арналған кроссовка', 27900, '#1f2430', 'solid', NULL, 'img/sneaker_city_black.jpg');

-- 5. ӨЛШЕМ КЕСТЕЛЕРІ және бастапқы қалдық: әр өнім үшін бір INSERT ... SELECT; sku = өнім коды + өлшем
--    қалдық өлшемге қарай: S = 3, M = 6, L = 5, XL = 2, аяқ киім = 4 дана
INSERT INTO dbo.product_sizes(product_id, size_label, sku, chest_cm, hem_cm, stock_qty)
SELECT p.id, s.size_label, CONCAT('TEE-001-', s.size_label), s.a, s.b, CASE s.size_label WHEN 'S' THEN 3 WHEN 'M' THEN 6 WHEN 'L' THEN 5 WHEN 'XL' THEN 2 ELSE 4 END
FROM dbo.products p CROSS JOIN (SELECT 'S' AS size_label, 98 AS a, 98 AS b UNION ALL SELECT 'M', 106, 106 UNION ALL SELECT 'L', 114, 114 UNION ALL SELECT 'XL', 122, 122) s
WHERE p.name = N'Футболка «TryOn» ақ';

INSERT INTO dbo.product_sizes(product_id, size_label, sku, chest_cm, hem_cm, stock_qty)
SELECT p.id, s.size_label, CONCAT('TEE-002-', s.size_label), s.a, s.b, CASE s.size_label WHEN 'S' THEN 3 WHEN 'M' THEN 6 WHEN 'L' THEN 5 WHEN 'XL' THEN 2 ELSE 4 END
FROM dbo.products p CROSS JOIN (SELECT 'S' AS size_label, 98 AS a, 98 AS b UNION ALL SELECT 'M', 106, 106 UNION ALL SELECT 'L', 114, 114 UNION ALL SELECT 'XL', 122, 122) s
WHERE p.name = N'Футболка «Stripe» көк-ақ';

INSERT INTO dbo.product_sizes(product_id, size_label, sku, chest_cm, hem_cm, stock_qty)
SELECT p.id, s.size_label, CONCAT('TEE-003-', s.size_label), s.a, s.b, CASE s.size_label WHEN 'S' THEN 3 WHEN 'M' THEN 6 WHEN 'L' THEN 5 WHEN 'XL' THEN 2 ELSE 4 END
FROM dbo.products p CROSS JOIN (SELECT 'S' AS size_label, 96 AS a, 96 AS b UNION ALL SELECT 'M', 104, 104 UNION ALL SELECT 'L', 112, 112 UNION ALL SELECT 'XL', 120, 120) s
WHERE p.name = N'Футболка «Basic» қара';

INSERT INTO dbo.product_sizes(product_id, size_label, sku, chest_cm, hem_cm, stock_qty)
SELECT p.id, s.size_label, CONCAT('SWE-001-', s.size_label), s.a, s.b, CASE s.size_label WHEN 'S' THEN 3 WHEN 'M' THEN 6 WHEN 'L' THEN 5 WHEN 'XL' THEN 2 ELSE 4 END
FROM dbo.products p CROSS JOIN (SELECT 'S' AS size_label, 102 AS a, 96 AS b UNION ALL SELECT 'M', 110, 104 UNION ALL SELECT 'L', 118, 112 UNION ALL SELECT 'XL', 126, 120) s
WHERE p.name = N'Свитер «Winter» көк';

INSERT INTO dbo.product_sizes(product_id, size_label, sku, chest_cm, hem_cm, stock_qty)
SELECT p.id, s.size_label, CONCAT('SWE-002-', s.size_label), s.a, s.b, CASE s.size_label WHEN 'S' THEN 3 WHEN 'M' THEN 6 WHEN 'L' THEN 5 WHEN 'XL' THEN 2 ELSE 4 END
FROM dbo.products p CROSS JOIN (SELECT 'S' AS size_label, 100 AS a, 94 AS b UNION ALL SELECT 'M', 108, 102 UNION ALL SELECT 'L', 116, 110 UNION ALL SELECT 'XL', 124, 118) s
WHERE p.name = N'Свитер «Classic» қара';

INSERT INTO dbo.product_sizes(product_id, size_label, sku, waist_cm, hip_cm, thigh_cm, stock_qty)
SELECT p.id, s.size_label, CONCAT('SHO-001-', s.size_label), s.a, s.b, s.c, CASE s.size_label WHEN 'S' THEN 3 WHEN 'M' THEN 6 WHEN 'L' THEN 5 WHEN 'XL' THEN 2 ELSE 4 END
FROM dbo.products p CROSS JOIN (SELECT 'S' AS size_label, 82 AS a, 98 AS b, 58 AS c UNION ALL SELECT 'M', 90, 106, 62 UNION ALL SELECT 'L', 98, 114, 67 UNION ALL SELECT 'XL', 106, 122, 72) s
WHERE p.name = N'Шорты «Active» қара';

INSERT INTO dbo.product_sizes(product_id, size_label, sku, waist_cm, hip_cm, thigh_cm, stock_qty)
SELECT p.id, s.size_label, CONCAT('SHO-002-', s.size_label), s.a, s.b, s.c, CASE s.size_label WHEN 'S' THEN 3 WHEN 'M' THEN 6 WHEN 'L' THEN 5 WHEN 'XL' THEN 2 ELSE 4 END
FROM dbo.products p CROSS JOIN (SELECT 'S' AS size_label, 84 AS a, 100 AS b, 60 AS c UNION ALL SELECT 'M', 92, 108, 64 UNION ALL SELECT 'L', 100, 116, 69 UNION ALL SELECT 'XL', 108, 124, 74) s
WHERE p.name = N'Шорты «Casual» хаки';

INSERT INTO dbo.product_sizes(product_id, size_label, sku, waist_cm, hip_cm, thigh_cm, stock_qty)
SELECT p.id, s.size_label, CONCAT('PAN-001-', s.size_label), s.a, s.b, s.c, CASE s.size_label WHEN 'S' THEN 3 WHEN 'M' THEN 6 WHEN 'L' THEN 5 WHEN 'XL' THEN 2 ELSE 4 END
FROM dbo.products p CROSS JOIN (SELECT 'S' AS size_label, 82 AS a, 98 AS b, 59 AS c UNION ALL SELECT 'M', 90, 106, 64 UNION ALL SELECT 'L', 98, 114, 69 UNION ALL SELECT 'XL', 106, 122, 74) s
WHERE p.name = N'Шалбар «Straight» сұр';

INSERT INTO dbo.product_sizes(product_id, size_label, sku, waist_cm, hip_cm, thigh_cm, stock_qty)
SELECT p.id, s.size_label, CONCAT('PAN-002-', s.size_label), s.a, s.b, s.c, CASE s.size_label WHEN 'S' THEN 3 WHEN 'M' THEN 6 WHEN 'L' THEN 5 WHEN 'XL' THEN 2 ELSE 4 END
FROM dbo.products p CROSS JOIN (SELECT 'S' AS size_label, 84 AS a, 100 AS b, 60 AS c UNION ALL SELECT 'M', 92, 108, 65 UNION ALL SELECT 'L', 100, 116, 70 UNION ALL SELECT 'XL', 108, 124, 75) s
WHERE p.name = N'Шалбар «Chino» қоңыр-сары';

INSERT INTO dbo.product_sizes(product_id, size_label, sku, length_cm, stock_qty)
SELECT p.id, s.size_label, CONCAT('SNK-001-', s.size_label), s.a, CASE s.size_label WHEN 'S' THEN 3 WHEN 'M' THEN 6 WHEN 'L' THEN 5 WHEN 'XL' THEN 2 ELSE 4 END
FROM dbo.products p CROSS JOIN (SELECT '40' AS size_label, 26.0 AS a UNION ALL SELECT '41', 26.7 UNION ALL SELECT '42', 27.3 UNION ALL SELECT '43', 28.0 UNION ALL SELECT '44', 28.7) s
WHERE p.name = N'Кроссовка «Runner» ақ';

INSERT INTO dbo.product_sizes(product_id, size_label, sku, length_cm, stock_qty)
SELECT p.id, s.size_label, CONCAT('SNK-002-', s.size_label), s.a, CASE s.size_label WHEN 'S' THEN 3 WHEN 'M' THEN 6 WHEN 'L' THEN 5 WHEN 'XL' THEN 2 ELSE 4 END
FROM dbo.products p CROSS JOIN (SELECT '39' AS size_label, 25.3 AS a UNION ALL SELECT '40', 26.0 UNION ALL SELECT '41', 26.7 UNION ALL SELECT '42', 27.3 UNION ALL SELECT '43', 28.0) s
WHERE p.name = N'Кроссовка «City» қара';

-- 6. СЕБЕТ
INSERT INTO dbo.cart_items(user_id, product_size_id, qty) VALUES
 ((SELECT id FROM dbo.users WHERE email = 'aliya@example.com'), (SELECT id FROM dbo.product_sizes WHERE sku = 'SWE-001-M'), 1),
 ((SELECT id FROM dbo.users WHERE email = 'zhandos@example.com'), (SELECT id FROM dbo.product_sizes WHERE sku = 'TEE-002-M'), 1);

-- 7. ТАПСЫРЫСТАР (сатып алу тізбегі: orders → order_items → payments → мәртебе → қайтару)

-- 7.1 Айгерім: футболка + шорты → төленді → жеткізілді → шорты қайтарылды (өлшемі үлкен)
INSERT INTO dbo.orders(customer_id, address_id)
SELECT u.id, a.id FROM dbo.users u JOIN dbo.addresses a ON a.user_id = u.id AND a.is_default = 1
WHERE u.email = 'aigerim@example.com';
-- тапсырыс жолдары: атау мен баға тікелей products кестесінен көшіріледі (снимок); қалдық пен соманы триггер есептейді
INSERT INTO dbo.order_items(order_id, product_size_id, product_name, unit_price, qty)
SELECT o.id, ps.id, p.name, p.price, 1
FROM dbo.orders o JOIN dbo.users u ON u.id = o.customer_id
CROSS JOIN dbo.product_sizes ps JOIN dbo.products p ON p.id = ps.product_id
WHERE u.email = 'aigerim@example.com' AND o.id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = u.id)
  AND ps.sku IN ('TEE-001-M', 'SHO-001-M');
INSERT INTO dbo.payments(order_id, amount, method, status, paid_at)
SELECT o.id, o.total_amount, 'kaspi', 'paid', SYSUTCDATETIME()
FROM dbo.orders o JOIN dbo.users u ON u.id = o.customer_id WHERE u.email = 'aigerim@example.com' AND o.id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = u.id);
UPDATE dbo.orders SET status = 'packed', manager_id = (SELECT id FROM dbo.users WHERE email = 'manager@tryon.kz')
WHERE id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = (SELECT id FROM dbo.users WHERE email = 'aigerim@example.com'));
UPDATE dbo.orders SET status = 'shipped', manager_id = (SELECT id FROM dbo.users WHERE email = 'manager@tryon.kz')
WHERE id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = (SELECT id FROM dbo.users WHERE email = 'aigerim@example.com'));
UPDATE dbo.orders SET status = 'delivered', manager_id = (SELECT id FROM dbo.users WHERE email = 'manager@tryon.kz')
WHERE id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = (SELECT id FROM dbo.users WHERE email = 'aigerim@example.com'));
-- қайтару: өтінім → менеджер бекітеді → ақша қайтарылады (refund_amount), қалдық қайтады (триггер)
INSERT INTO dbo.return_requests(order_item_id, qty, reason, comment)
SELECT oi.id, 1, 'too_big', N'Белі кең, өлшем M үлкен болып шықты'
FROM dbo.order_items oi JOIN dbo.orders o ON o.id = oi.order_id WHERE o.customer_id = (SELECT id FROM dbo.users WHERE email = 'aigerim@example.com') AND oi.product_size_id = (SELECT id FROM dbo.product_sizes WHERE sku = 'SHO-001-M');
UPDATE dbo.return_requests SET status = 'approved', handled_by = (SELECT id FROM dbo.users WHERE email = 'manager@tryon.kz') WHERE status = 'requested';
UPDATE dbo.return_requests
SET status = 'refunded', refund_amount = (SELECT oi.unit_price * return_requests.qty FROM dbo.order_items oi WHERE oi.id = return_requests.order_item_id)
WHERE status = 'approved';

-- 7.2 Данияр: свитер + шалбар → төленді → жеткізілді
INSERT INTO dbo.orders(customer_id, address_id)
SELECT u.id, a.id FROM dbo.users u JOIN dbo.addresses a ON a.user_id = u.id AND a.is_default = 1
WHERE u.email = 'daniyar@example.com';
-- тапсырыс жолдары: атау мен баға тікелей products кестесінен көшіріледі (снимок); қалдық пен соманы триггер есептейді
INSERT INTO dbo.order_items(order_id, product_size_id, product_name, unit_price, qty)
SELECT o.id, ps.id, p.name, p.price, 1
FROM dbo.orders o JOIN dbo.users u ON u.id = o.customer_id
CROSS JOIN dbo.product_sizes ps JOIN dbo.products p ON p.id = ps.product_id
WHERE u.email = 'daniyar@example.com' AND o.id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = u.id)
  AND ps.sku IN ('SWE-001-XL', 'PAN-001-XL');
INSERT INTO dbo.payments(order_id, amount, method, status, paid_at)
SELECT o.id, o.total_amount, 'card', 'paid', SYSUTCDATETIME()
FROM dbo.orders o JOIN dbo.users u ON u.id = o.customer_id WHERE u.email = 'daniyar@example.com' AND o.id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = u.id);
UPDATE dbo.orders SET status = 'packed', manager_id = (SELECT id FROM dbo.users WHERE email = 'manager@tryon.kz')
WHERE id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = (SELECT id FROM dbo.users WHERE email = 'daniyar@example.com'));
UPDATE dbo.orders SET status = 'shipped', manager_id = (SELECT id FROM dbo.users WHERE email = 'manager@tryon.kz')
WHERE id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = (SELECT id FROM dbo.users WHERE email = 'daniyar@example.com'));
UPDATE dbo.orders SET status = 'delivered', manager_id = (SELECT id FROM dbo.users WHERE email = 'manager@tryon.kz')
WHERE id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = (SELECT id FROM dbo.users WHERE email = 'daniyar@example.com'));

-- 7.3 Әлия: кроссовка → төленді → жолда
INSERT INTO dbo.orders(customer_id, address_id)
SELECT u.id, a.id FROM dbo.users u JOIN dbo.addresses a ON a.user_id = u.id AND a.is_default = 1
WHERE u.email = 'aliya@example.com';
-- тапсырыс жолдары: атау мен баға тікелей products кестесінен көшіріледі (снимок); қалдық пен соманы триггер есептейді
INSERT INTO dbo.order_items(order_id, product_size_id, product_name, unit_price, qty)
SELECT o.id, ps.id, p.name, p.price, 1
FROM dbo.orders o JOIN dbo.users u ON u.id = o.customer_id
CROSS JOIN dbo.product_sizes ps JOIN dbo.products p ON p.id = ps.product_id
WHERE u.email = 'aliya@example.com' AND o.id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = u.id)
  AND ps.sku IN ('SNK-002-40');
INSERT INTO dbo.payments(order_id, amount, method, status, paid_at)
SELECT o.id, o.total_amount, 'kaspi', 'paid', SYSUTCDATETIME()
FROM dbo.orders o JOIN dbo.users u ON u.id = o.customer_id WHERE u.email = 'aliya@example.com' AND o.id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = u.id);
UPDATE dbo.orders SET status = 'packed', manager_id = (SELECT id FROM dbo.users WHERE email = 'manager@tryon.kz')
WHERE id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = (SELECT id FROM dbo.users WHERE email = 'aliya@example.com'));
UPDATE dbo.orders SET status = 'shipped', manager_id = (SELECT id FROM dbo.users WHERE email = 'manager@tryon.kz')
WHERE id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = (SELECT id FROM dbo.users WHERE email = 'aliya@example.com'));

-- 7.4 Айгерім: екінші тапсырыс, свитер L (жүйе ұсынған өлшем) → төленді → жиналды
INSERT INTO dbo.orders(customer_id, address_id)
SELECT u.id, a.id FROM dbo.users u JOIN dbo.addresses a ON a.user_id = u.id AND a.is_default = 1
WHERE u.email = 'aigerim@example.com';
-- тапсырыс жолдары: атау мен баға тікелей products кестесінен көшіріледі (снимок); қалдық пен соманы триггер есептейді
INSERT INTO dbo.order_items(order_id, product_size_id, product_name, unit_price, qty)
SELECT o.id, ps.id, p.name, p.price, 1
FROM dbo.orders o JOIN dbo.users u ON u.id = o.customer_id
CROSS JOIN dbo.product_sizes ps JOIN dbo.products p ON p.id = ps.product_id
WHERE u.email = 'aigerim@example.com' AND o.id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = u.id)
  AND ps.sku IN ('SWE-002-L');
INSERT INTO dbo.payments(order_id, amount, method, status, paid_at)
SELECT o.id, o.total_amount, 'card', 'paid', SYSUTCDATETIME()
FROM dbo.orders o JOIN dbo.users u ON u.id = o.customer_id WHERE u.email = 'aigerim@example.com' AND o.id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = u.id);
UPDATE dbo.orders SET status = 'packed', manager_id = (SELECT id FROM dbo.users WHERE email = 'manager@tryon.kz')
WHERE id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = (SELECT id FROM dbo.users WHERE email = 'aigerim@example.com'));

-- 7.5 Әлия: футболка M (жүйе ұсынған өлшем), төлем әлі күтілуде (pending), мәртебе new
INSERT INTO dbo.orders(customer_id, address_id)
SELECT u.id, a.id FROM dbo.users u JOIN dbo.addresses a ON a.user_id = u.id AND a.is_default = 1
WHERE u.email = 'aliya@example.com';
-- тапсырыс жолдары: атау мен баға тікелей products кестесінен көшіріледі (снимок); қалдық пен соманы триггер есептейді
INSERT INTO dbo.order_items(order_id, product_size_id, product_name, unit_price, qty)
SELECT o.id, ps.id, p.name, p.price, 1
FROM dbo.orders o JOIN dbo.users u ON u.id = o.customer_id
CROSS JOIN dbo.product_sizes ps JOIN dbo.products p ON p.id = ps.product_id
WHERE u.email = 'aliya@example.com' AND o.id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = u.id)
  AND ps.sku IN ('TEE-003-M');
INSERT INTO dbo.payments(order_id, amount, method, status, paid_at)
SELECT o.id, o.total_amount, 'kaspi', 'pending', NULL
FROM dbo.orders o JOIN dbo.users u ON u.id = o.customer_id WHERE u.email = 'aliya@example.com' AND o.id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = u.id);

-- 7.6 Данияр: шорты, төлеместен бас тартты → қалдық қайтады (триггер)
INSERT INTO dbo.orders(customer_id, address_id)
SELECT u.id, a.id FROM dbo.users u JOIN dbo.addresses a ON a.user_id = u.id AND a.is_default = 1
WHERE u.email = 'daniyar@example.com';
-- тапсырыс жолдары: атау мен баға тікелей products кестесінен көшіріледі (снимок); қалдық пен соманы триггер есептейді
INSERT INTO dbo.order_items(order_id, product_size_id, product_name, unit_price, qty)
SELECT o.id, ps.id, p.name, p.price, 1
FROM dbo.orders o JOIN dbo.users u ON u.id = o.customer_id
CROSS JOIN dbo.product_sizes ps JOIN dbo.products p ON p.id = ps.product_id
WHERE u.email = 'daniyar@example.com' AND o.id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = u.id)
  AND ps.sku IN ('SHO-002-XL');
UPDATE dbo.orders SET status = 'cancelled', manager_id = (SELECT id FROM dbo.users WHERE email = 'manager@tryon.kz')
WHERE id = (SELECT MAX(id) FROM dbo.orders WHERE customer_id = (SELECT id FROM dbo.users WHERE email = 'daniyar@example.com'));
GO
