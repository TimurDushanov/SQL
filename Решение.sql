--1.Выведите название самолетов, которые имеют менее 50 посадочных мест?
select a.model, count(s.seat_no) 
from aircrafts a 
join seats s on s.aircraft_code = a.aircraft_code 
group by a.aircraft_code 
having count(s.seat_no) < 50

--2.Выведите процентное изменение ежемесячной суммы бронирования билетов, 
--округленной до сотых.
select date_re, amount, round((amount/(laga/100) - laga/(laga/100)), 2)
from (select date_re, amount,
	lag (amount, 1) over(order by date_re) as laga,
	lead (amount, 2) over (order by date_re) as leada
	from(select date_trunc('month', book_date)::date as date_re, sum(total_amount) as amount
	from bookings b 
	group by 1
	order by 1) qwe) qwer

--3.Выведите названия самолетов не имеющих бизнес - класс. Решение должно быть 
--через функцию array_agg.
select array_agg(qwe.model_name)
from (select a.model as model_name, array_agg(distinct fare_conditions) as conditions
	from aircrafts a 
	join seats s on s.aircraft_code = a.aircraft_code
	group by 1) qwe
where not 'Business' = any(qwe.conditions)


--4.Вывести накопительный итог количества мест в самолетах по каждому аэропорту на каждый
--день, учитывая только те самолеты, которые летали пустыми и только те дни, где из 
--одного аэропорта таких самолетов вылетало более одного.
--В результате должны быть код аэропорта, дата, количество пустых мест и накопительный итог.


--5.Найдите процентное соотношение перелетов по маршрутам от общего количества перелетов. 
--Выведите в результат названия аэропортов и процентное отношение.
--Решение должно быть через оконную функцию.

select qwer.flight_no, qwer.departure_airport, qwer.arrival_airport,
lead (qwer.counter_by_route/(select count(flight_id) from flights f2)*100 , 0) over() as percents
from (
	select qwe.flight_no, a2.airport_name as departure_airport, a3.airport_name as arrival_airport,
	sum(qwe.counter) as counter_by_route
	from(select *, count(flight_id) as counter
		from flights f 
		group by flight_id
		order by flight_no) qwe
	join airports a2 on a2.airport_code = qwe.departure_airport
	join airports a3 on a3.airport_code = qwe.arrival_airport
	group by qwe.flight_no, a2.airport_name, a3.airport_name, qwe.counter
	order by 1
	) qwer

--6.Выведите количество пассажиров по каждому коду сотового оператора, если учесть, 
--что код оператора - это три символа после +7
select distinct qwer.phone_operator, sum(qwer.counter) 
from(select qwe.passenger_id, qwe.passenger_name, substring(qwe.phone from 3 for 3) as phone_operator,
	count(qwe.passenger_id) as counter
	from(select *, contact_data ->> 'phone' as phone
	from tickets) qwe
	group by qwe.passenger_id, qwe.passenger_name, qwe.phone) qwer
group by 1

--7.Классифицируйте финансовые обороты (сумма стоимости билетов) по маршрутам:
--До 50 млн - low
--От 50 млн включительно до 150 млн - middle
--От 150 млн включительно - high
--Выведите в результат количество маршрутов в каждом полученном классе.
select qwer.oborot, sum(qwer.row_number) 
from(select *, row_number() over(partition by qwe.flight_no),
	case when qwe.amount_f < 50000000 then 'low'
	when qwe.amount_f > 150000000 then 'hight'
	when qwe.amount_f between 50000000 and 150000000 then 'middle'
	end as oborot
	from(select f.flight_no, sum(amount) as amount_f
		from ticket_flights tf 
		join flights f on f.flight_id = tf.flight_id 
		group by f.flight_no 
		order by f.flight_no) qwe) qwer
group by qwer.oborot


--8.Вычислите медиану стоимости билетов, медиану размера бронирования 
--и отношение медианы бронирования к медиане стоимости билетов, округленной до сотых.
with cte as (
		select percentile_disc(0.5)
		within group (order by amount) as price_of_ticket
		from ticket_flights tf),
ctr as(
		select percentile_disc(0.5)
		within group (order by total_amount) as price_of_booking
		from bookings b)
select *, round(ctr.price_of_booking/cte.price_of_ticket, 2) as booking_to_ticket
from cte, ctr

--9.Найдите значение минимальной стоимости полета 1 км для пассажиров. То есть 
--нужно найти расстояние между аэропортами и с учетом стоимости билетов получить 
--искомый результат.
--Для поиска расстояния между двумя точка на поверхности Земли нужно использовать 
--дополнительный модуль earthdistance (https://postgrespro.ru/docs/postgresql/15/earthdistance). 
--Для работы данного модуля нужно установить еще один модуль cube (https://postgrespro.ru/docs/postgresql/15/cube). 
--Установка дополнительных модулей происходит через оператор create extension название_модуля.
--Функция earth_distance возвращает результат в метрах.
--В облачной базе данных модули уже установлены.

with cte as (select flight_id, sum(amount) as amount
	from ticket_flights tf
	group by flight_id 
	order by flight_id)
select min(cte.amount/(earth_distance(ll_to_earth(a.latitude, a.longitude), ll_to_earth(a2.latitude, a2.longitude))/1000))
from flights f 
join airports a on a.airport_code = f.departure_airport 
join ticket_flights tf on tf.flight_id = f.flight_id
join airports a2 on a2.airport_code = f.arrival_airport 
join cte cte on cte.flight_id = f.flight_id 