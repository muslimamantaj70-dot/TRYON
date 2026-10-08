/* TryOn (SQL Server): JOIN сұраулары. Кестелердің логикалық байланысын көрсетеді.
   02_seed.sql орындалғаннан кейін, 05_update_delete.sql-ге дейін іске қосыңыз.
   «Тұтастықты тексеру» сұрауларының (J4, J5) нәтижесі БОС болуы керек: бос болса, байланыстар дұрыс. */
USE TryOn;
GO

-- J1. Каталог: тауар → санат → ата-санат → сатушы дүкені
-- Байланыс: products кестесі categories (санат), categories өзімен (ата-санат, LEFT JOIN, себебі ата-санаты жоқ санат болуы мүмкін) және users (сатушы, shop_name) кестелерімен байланысады.
SELECT p.name AS product, c.name AS category, pc.name AS parent_category, s.shop_name, p.price
FROM dbo.products p
JOIN dbo.categories c ON c.id = p.category_id
LEFT JOIN dbo.categories pc ON pc.id = c.parent_id
JOIN dbo.users s ON s.id = p.seller_id
ORDER BY pc.name, c.name, p.name;

-- J2. Тауар → өлшем кестесі → қалдық (JOIN + топтау)
-- Байланыс: Бір тауардың бірнеше өлшемі бар (1:N); топтау әр тауар үшін өлшем санын және қоймадағы қалдықты есептейді.
SELECT p.name AS product, COUNT(ps.id) AS sizes, SUM(ps.stock_qty) AS total_stock
FROM dbo.products p
JOIN dbo.product_sizes ps ON ps.product_id = p.id
GROUP BY p.id, p.name
ORDER BY p.name;

-- J3. Тапсырыстың толық тізбегі: тапсырыс → клиент → мекенжай → жол → өлшем → тауар → сатушы
-- Байланыс: Жеті кесте тізбектеліп байланысады: orders → users, orders → addresses, orders → order_items → product_sizes → products → users (сатушы).
SELECT o.id AS order_id, u.full_name AS customer, a.city, o.status, oi.product_name, ps.sku, oi.unit_price, s.shop_name
FROM dbo.orders o
JOIN dbo.users u ON u.id = o.customer_id
JOIN dbo.addresses a ON a.id = o.address_id
JOIN dbo.order_items oi ON oi.order_id = o.id
JOIN dbo.product_sizes ps ON ps.id = oi.product_size_id
JOIN dbo.products p ON p.id = ps.product_id
JOIN dbo.users s ON s.id = p.seller_id
ORDER BY o.id, ps.sku;

-- J4. Тұтастықты тексеру: тапсырыс жолындағы атау мен баға өнім кестесімен сәйкес пе?
-- Байланыс: Тапсырыс жолы өнімнің «снимогын» сақтайды. Бастапқы деректерде айырмашылық болмауы керек, сондықтан нәтиже бос болуы тиіс (0 жол).
SELECT oi.id AS order_item_id, oi.product_name, p.name AS current_name, oi.unit_price, p.price AS current_price
FROM dbo.order_items oi
JOIN dbo.product_sizes ps ON ps.id = oi.product_size_id
JOIN dbo.products p ON p.id = ps.product_id
WHERE oi.product_name <> p.name OR oi.unit_price <> p.price;

-- J5. Тұтастықты тексеру: тапсырыс сомасы жолдар сомасына тең бе?
-- Байланыс: orders.total_amount триггермен жаңарады; оны order_items қосындысымен салыстырамыз. Нәтиже бос болуы керек (0 жол).
SELECT o.id AS order_id, o.total_amount, SUM(oi.qty * oi.unit_price) AS items_sum
FROM dbo.orders o
JOIN dbo.order_items oi ON oi.order_id = o.id
GROUP BY o.id, o.total_amount
HAVING o.total_amount <> SUM(oi.qty * oi.unit_price);

-- J6. Тапсырыс және төлем: LEFT JOIN (төлемі жоқ тапсырыс та көрінеді)
-- Байланыс: Барлық тапсырыс көрсетіледі; төлемі жоқ тапсырыстың (бас тартылған) төлем бағандары NULL болады.
SELECT o.id AS order_id, o.status, o.total_amount, pm.method, pm.status AS payment_status, pm.amount
FROM dbo.orders o
LEFT JOIN dbo.payments pm ON pm.order_id = o.id
ORDER BY o.id;

-- J7. Қайтару тізбегі: қайтару → тапсырыс жолы → тапсырыс → клиент, және өңдеген менеджер
-- Байланыс: return_requests order_items арқылы тапсырысқа және клиентке байланады; handled_by арқылы users кестесіне қайта сілтейді (менеджер).
SELECT rr.id AS return_id, u.full_name AS customer, oi.product_name, rr.qty, rr.reason, rr.status, rr.refund_amount, m.full_name AS handled_by
FROM dbo.return_requests rr
JOIN dbo.order_items oi ON oi.id = rr.order_item_id
JOIN dbo.orders o ON o.id = oi.order_id
JOIN dbo.users u ON u.id = o.customer_id
LEFT JOIN dbo.users m ON m.id = rr.handled_by;

-- J8. fit_rules байланысы: киім түрі арқылы тауарға қолданылатын отыру ережелері
-- Байланыс: fit_rules.garment_type → garment_types.code ← products.garment_type: ереже тауарға киім түрі арқылы байланады. Свитердің шектері басқаша (ол еркін киіледі).
SELECT p.name AS product, gt.name AS garment_type, r.zone, r.tight_below, r.loose_above
FROM dbo.products p
JOIN dbo.garment_types gt ON gt.code = p.garment_type
JOIN dbo.fit_rules r ON r.garment_type = gt.code
WHERE p.name IN (N'Футболка «TryOn» ақ', N'Свитер «Winter» көк', N'Шорты «Active» қара')
ORDER BY p.name, r.zone;

-- J9. LEFT JOIN: әлі тапсырыс бермеген клиенттер
-- Байланыс: Клиент (рөл бойынша сүзгі) тапсырыспен LEFT JOIN жасалады; тапсырысы жоқ жолдарда o.id IS NULL.
SELECT u.full_name, u.email
FROM dbo.users u
JOIN dbo.roles r ON r.id = u.role_id AND r.code = 'client'
LEFT JOIN dbo.orders o ON o.customer_id = u.id
WHERE o.id IS NULL;

-- J10. Сатушы бойынша сатылым (бас тартылған тапсырыстарсыз)
-- Байланыс: Сатушыға жету жолы: order_items → product_sizes → products → users (сатушы); топтау және сүзгі (status).
SELECT s.shop_name, COUNT(DISTINCT o.id) AS orders, SUM(oi.qty * oi.unit_price) AS revenue
FROM dbo.order_items oi
JOIN dbo.orders o ON o.id = oi.order_id AND o.status <> 'cancelled'
JOIN dbo.product_sizes ps ON ps.id = oi.product_size_id
JOIN dbo.products p ON p.id = ps.product_id
JOIN dbo.users s ON s.id = p.seller_id
GROUP BY s.shop_name
ORDER BY revenue DESC;

-- J11. Отыру есебі: клиент өлшемі мен киім өлшемі fit_rules шектерімен салыстырылады
-- Байланыс: v_fit_zones көрінісі body_profiles (клиент өлшемі), product_sizes (киім өлшемі) және fit_rules (шектер) кестелерін біріктіреді. Данияр мен «Свитер «Winter» көк».
SELECT size_label, zone, body_cm, garment_cm, diff_cm, tight_below, loose_above, verdict
FROM dbo.v_fit_zones
WHERE user_id = (SELECT id FROM dbo.users WHERE email = 'daniyar@example.com') AND product_id = (SELECT id FROM dbo.products WHERE name = N'Свитер «Winter» көк')
ORDER BY size_rank, zone;

-- J12. Ұсынылатын өлшем: клиент × тауар
-- Байланыс: v_recommended_size көрінісі қысатын аймағы жоқ және қоймада бар ең кіші өлшемді таңдайды.
SELECT u.full_name AS customer, p.name AS product, r.size_label AS recommended_size
FROM dbo.v_recommended_size r
JOIN dbo.users u ON u.id = r.user_id
JOIN dbo.products p ON p.id = r.product_id
WHERE u.email IN ('aigerim@example.com', 'daniyar@example.com') AND p.garment_type IN ('tee', 'sweater')
ORDER BY u.full_name, p.name;

-- J13. Қайтару және отыру үкімі: қайтарылған өлшем үшін жүйе қандай үкім берген?
-- Байланыс: return_requests, order_items, product_sizes және v_size_verdict байланысады: «өлшемі үлкен» себебімен қайтарылған шорты үшін жүйе «бос» (loose) үкімін береді, яғни қайтару отыру логикасымен сәйкес.
SELECT u.full_name AS customer, oi.product_name, ps.size_label, rr.reason, v.verdict AS fit_verdict
FROM dbo.return_requests rr
JOIN dbo.order_items oi ON oi.id = rr.order_item_id
JOIN dbo.orders o ON o.id = oi.order_id
JOIN dbo.users u ON u.id = o.customer_id
JOIN dbo.product_sizes ps ON ps.id = oi.product_size_id
JOIN dbo.v_size_verdict v ON v.user_id = o.customer_id AND v.product_size_id = oi.product_size_id;

GO
