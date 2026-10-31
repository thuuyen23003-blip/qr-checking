insert into ca_lam (thu, ten_ca, gio_bat_dau, gio_ket_thuc)
select t.d, c.ten, c.bd, c.kt from (values (1),(3),(5)) t(d), (values ('Ca 1','17:45'::time,'19:15'::time),('Ca 2','19:30','21:00')) c(ten,bd,kt)
union all
select t.d, c.ten, c.bd, c.kt from (values (2),(4)) t(d), (values ('Ca 1','17:30'::time,'19:30'::time),('Ca 2','19:30','21:00')) c(ten,bd,kt);
