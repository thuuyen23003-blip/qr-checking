create table giao_vien (
  id uuid primary key references auth.users on delete cascade,
  ma text unique not null,
  ho_ten text not null,
  vai_tro text not null default 'giao_vien' check (vai_tro in ('admin','giao_vien')),
  so_dien_thoai text,
  lop_day text[] not null default '{}',
  dang_lam boolean not null default true,
  trang_thai text not null default 'lam' check (trang_thai in ('lam','ban','phep','nghi')),
  tu_ngay date,
  den_ngay date,
  ghi_chu text,
  don_gia_ca int check (don_gia_ca >= 0),
  phu_cap int not null default 0 check (phu_cap >= 0),
  phai_doi_mat_khau boolean not null default false,
  constraint sdt_bat_buoc check (vai_tro = 'admin' or length(regexp_replace(coalesce(so_dien_thoai, ''), '\D', '', 'g')) >= 9)
);

create table ca_lam (
  id serial primary key,
  thu smallint not null check (thu between 1 and 7),
  ten_ca text not null,
  gio_bat_dau time not null,
  gio_ket_thuc time not null check (gio_ket_thuc > gio_bat_dau)
);

create table lich_day (
  giao_vien_id uuid references giao_vien on delete cascade,
  ca_id int references ca_lam on delete cascade,
  primary key (giao_vien_id, ca_id)
);

create table cham_cong (
  id bigserial primary key,
  giao_vien_id uuid not null references giao_vien on delete cascade,
  ca_id int references ca_lam on delete set null,
  ngay date not null,
  ten_ca text not null,
  gio_bat_dau time not null,
  gio_ket_thuc time not null,
  gio_quet timestamptz not null default now(),
  nguon text not null default 'quet' check (nguon in ('quet','bu_gv','bu_admin')),
  tre_phut int not null default 0 check (tre_phut >= 0),
  unique (giao_vien_id, ca_id, ngay)
);

create table don_tu (
  id bigserial primary key,
  giao_vien_id uuid not null references giao_vien on delete cascade,
  loai text not null check (loai in ('phep','ban')),
  tu_ngay date not null,
  den_ngay date not null check (den_ngay >= tu_ngay),
  ly_do text,
  trang_thai text not null default 'cho' check (trang_thai in ('cho','duyet','tu')),
  tao_luc timestamptz not null default now()
);

create table thuong_phat (
  id bigserial primary key,
  giao_vien_id uuid not null references giao_vien on delete cascade,
  thang date not null,
  loai text not null check (loai in ('thuong','phat')),
  so_tien int not null check (so_tien > 0),
  ly_do text,
  tao_luc timestamptz not null default now()
);

create table chot_luong (thang date primary key, chot_luc timestamptz not null default now());
create table xuat_thang (thang date primary key, da_xuat boolean not null default false, ngay_xuat timestamptz);
create table cai_dat (khoa text primary key, gia_tri text not null);
insert into cai_dat values
  ('ten_trung_tam', ''), ('slogan', 'Quản lý chấm công đơn giản hơn.'), ('mau_chu_dao', ''), ('dia_chi_web', ''),
  ('giu_thang', '6'), ('bu_toi_da_ngay', '3'), ('quet_som_phut', '0'), ('quet_sau_phut', '60'), ('ma_qr_moi_ngay', 'false'),
  ('don_gia_ca', '0'), ('phat_tre', '0');

create table ma_qr (ma text primary key, ngay date, hieu_luc boolean not null default true);
create unique index ma_qr_ngay on ma_qr (ngay) where ngay is not null;
insert into ma_qr (ma) values (md5(random()::text));

create or replace function la_admin() returns boolean
language sql stable security definer set search_path = public as
$$ select exists (select 1 from giao_vien where id = auth.uid() and vai_tro = 'admin') $$;

create or replace function quet_cham_cong(p_ma text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_gv giao_vien;
  v_now timestamp := now() at time zone 'Asia/Ho_Chi_Minh';
  v_ngay date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
  v_som int := (select gia_tri::int from cai_dat where khoa = 'quet_som_phut');
  v_phut int := (select gia_tri::int from cai_dat where khoa = 'quet_sau_phut');
  v_moi_ngay boolean := (select gia_tri::boolean from cai_dat where khoa = 'ma_qr_moi_ngay');
  v_dau time; v_cuoi time; v_n int; v_ca jsonb;
begin
  select * into v_gv from giao_vien where id = auth.uid() and dang_lam and vai_tro = 'giao_vien';
  if not found then return jsonb_build_object('ket_qua', 'khong_hop_le'); end if;
  if (v_gv.trang_thai = 'nghi' and (v_gv.tu_ngay is null or v_ngay >= v_gv.tu_ngay))
     or (v_gv.trang_thai in ('ban', 'phep') and v_ngay between v_gv.tu_ngay and v_gv.den_ngay)
     or exists (select 1 from don_tu d where d.giao_vien_id = v_gv.id and d.trang_thai = 'duyet' and v_ngay between d.tu_ngay and d.den_ngay) then
    return jsonb_build_object('ket_qua', 'dang_nghi');
  end if;
  if not exists (select 1 from ma_qr where ma = p_ma and hieu_luc and (not v_moi_ngay or ngay = v_ngay)) then
    return jsonb_build_object('ket_qua', 'ma_sai');
  end if;
  select min(gio_ket_thuc), max(gio_ket_thuc) into v_dau, v_cuoi from ca_lam where thu = extract(isodow from v_ngay);
  if v_dau is null or v_now::time < v_dau - make_interval(mins => v_som) or v_now::time > v_cuoi + make_interval(mins => v_phut) then
    return jsonb_build_object('ket_qua', 'ngoai_gio');
  end if;
  with moi as (
    insert into cham_cong (giao_vien_id, ca_id, ngay, ten_ca, gio_bat_dau, gio_ket_thuc, nguon)
    select v_gv.id, c.id, v_ngay, c.ten_ca, c.gio_bat_dau, c.gio_ket_thuc, 'quet'
    from lich_day l join ca_lam c on c.id = l.ca_id
    where l.giao_vien_id = v_gv.id and c.thu = extract(isodow from v_ngay) and c.gio_ket_thuc <= v_now::time
    on conflict (giao_vien_id, ca_id, ngay) do nothing
    returning ca_id)
  select count(*), coalesce(jsonb_agg(ca_id), '[]'::jsonb) into v_n, v_ca from moi;
  return jsonb_build_object('ket_qua', case when v_n > 0 then 'thanh_cong' else 'khong_co_ca_moi' end,
                            'ho_ten', v_gv.ho_ten, 'gio_quet', v_now, 'ca_ids', v_ca);
end $$;

create or replace function xac_nhan_bu(p_ca_id int, p_ngay date) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_han int := (select gia_tri::int from cai_dat where khoa = 'bu_toi_da_ngay');
  v_hom_nay date := (now() at time zone 'Asia/Ho_Chi_Minh')::date;
begin
  if p_ngay > v_hom_nay or p_ngay < v_hom_nay - v_han then
    raise exception 'Quá hạn xác nhận bù, hãy liên hệ quản lý';
  end if;
  if exists (select 1 from chot_luong where thang = date_trunc('month', p_ngay)::date) then
    raise exception 'Tháng này đã chốt lương';
  end if;
  insert into cham_cong (giao_vien_id, ca_id, ngay, ten_ca, gio_bat_dau, gio_ket_thuc, nguon)
  select l.giao_vien_id, c.id, p_ngay, c.ten_ca, c.gio_bat_dau, c.gio_ket_thuc, 'bu_gv'
  from lich_day l join ca_lam c on c.id = l.ca_id
  where l.giao_vien_id = auth.uid() and c.id = p_ca_id and c.thu = extract(isodow from p_ngay)
  on conflict do nothing;
  if not found then raise exception 'Ca không có trong lịch của bạn hoặc đã được xác nhận'; end if;
end $$;

create or replace function doi_ma_qr() returns text
language plpgsql security definer set search_path = public as $$
declare v_ma text := md5(random()::text || clock_timestamp()::text);
begin
  if not la_admin() then raise exception 'Không có quyền'; end if;
  update ma_qr set hieu_luc = false where ngay is null;
  insert into ma_qr (ma) values (v_ma);
  return v_ma;
end $$;

create or replace function tao_ma_qr_ngay() returns void
language sql security definer set search_path = public as $$
  insert into ma_qr (ma, ngay) values (md5(random()::text || clock_timestamp()::text), (now() at time zone 'Asia/Ho_Chi_Minh')::date)
  on conflict (ngay) where ngay is not null do nothing
$$;

create or replace function tinh_luong(p_thang date)
returns table (giao_vien_id uuid, ho_ten text, so_ca bigint, so_lan_tre bigint, don_gia int, tien_ca bigint, phu_cap int, thuong bigint, phat bigint, phat_tre bigint, thuc_nhan bigint)
language sql stable set search_path = public as $$
  with b as (
    select g.id, g.ho_ten, g.phu_cap,
           coalesce(g.don_gia_ca, (select gia_tri::int from cai_dat where khoa = 'don_gia_ca')) as dg,
           (select gia_tri::int from cai_dat where khoa = 'phat_tre') as pt,
           count(c.id) as so_ca,
           count(c.id) filter (where c.tre_phut > 0) as tre
    from giao_vien g
    left join cham_cong c on c.giao_vien_id = g.id and date_trunc('month', c.ngay) = date_trunc('month', p_thang)
    where g.vai_tro = 'giao_vien'
    group by g.id
  )
  select b.id, b.ho_ten, b.so_ca, b.tre, b.dg, (b.so_ca * b.dg)::bigint, b.phu_cap, x.th, x.ph, (b.tre * b.pt)::bigint,
         (b.so_ca * b.dg + b.phu_cap + x.th - x.ph - b.tre * b.pt)::bigint
  from b
  cross join lateral (
    select coalesce(sum(t.so_tien) filter (where t.loai = 'thuong'), 0)::bigint as th,
           coalesce(sum(t.so_tien) filter (where t.loai = 'phat'), 0)::bigint as ph
    from thuong_phat t
    where t.giao_vien_id = b.id and t.thang = date_trunc('month', p_thang)::date
  ) x
$$;

revoke execute on function quet_cham_cong(text), xac_nhan_bu(int, date), doi_ma_qr(), tao_ma_qr_ngay(), tinh_luong(date) from public;
grant execute on function quet_cham_cong(text), xac_nhan_bu(int, date), tinh_luong(date), doi_ma_qr() to authenticated;

create or replace view v_bang_cong_thang with (security_invoker = true) as
select g.ma, g.ho_ten, c.ngay, c.ten_ca, c.gio_bat_dau, c.gio_ket_thuc,
       (c.gio_quet at time zone 'Asia/Ho_Chi_Minh')::time(0) as gio_quet, c.nguon, c.tre_phut
from cham_cong c join giao_vien g on g.id = c.giao_vien_id;

create or replace function chan_sua_giao_vien() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not la_admin() and (new.ma, new.ho_ten, new.vai_tro, new.lop_day, new.dang_lam, new.trang_thai, new.tu_ngay, new.den_ngay, new.ghi_chu, new.don_gia_ca, new.phu_cap, new.phai_doi_mat_khau)
     is distinct from (old.ma, old.ho_ten, old.vai_tro, old.lop_day, old.dang_lam, old.trang_thai, old.tu_ngay, old.den_ngay, old.ghi_chu, old.don_gia_ca, old.phu_cap, old.phai_doi_mat_khau) then
    raise exception 'Chỉ quản trị viên được sửa thông tin này';
  end if;
  return new;
end $$;
create trigger trg_chan_sua before update on giao_vien for each row execute function chan_sua_giao_vien();

alter table giao_vien enable row level security;
alter table ca_lam enable row level security;
alter table lich_day enable row level security;
alter table cham_cong enable row level security;
alter table don_tu enable row level security;
alter table thuong_phat enable row level security;
alter table chot_luong enable row level security;
alter table xuat_thang enable row level security;
alter table cai_dat enable row level security;
alter table ma_qr enable row level security;

create policy xem_giao_vien on giao_vien for select using (id = auth.uid() or la_admin());
create policy sua_sdt on giao_vien for update using (id = auth.uid()) with check (id = auth.uid());
create policy xem_ca on ca_lam for select to authenticated using (true);
create policy xem_lich on lich_day for select using (giao_vien_id = auth.uid() or la_admin());
create policy xem_cong on cham_cong for select using (giao_vien_id = auth.uid() or la_admin());
create policy xem_don on don_tu for select using (giao_vien_id = auth.uid() or la_admin());
create policy gui_don on don_tu for insert with check (giao_vien_id = auth.uid() and trang_thai = 'cho');
create policy huy_don on don_tu for delete using (giao_vien_id = auth.uid() and trang_thai = 'cho');
create policy xem_thuong_phat on thuong_phat for select using (giao_vien_id = auth.uid() or la_admin());
create policy xem_chot on chot_luong for select to authenticated using (true);
create policy xem_cai_dat on cai_dat for select to authenticated using (true);
create policy admin_giao_vien on giao_vien for all using (la_admin()) with check (la_admin());
create policy admin_ca on ca_lam for all using (la_admin()) with check (la_admin());
create policy admin_lich on lich_day for all using (la_admin()) with check (la_admin());
create policy admin_cong on cham_cong for all using (la_admin()) with check (la_admin());
create policy admin_don on don_tu for all using (la_admin()) with check (la_admin());
create policy admin_thuong_phat on thuong_phat for all using (la_admin()) with check (la_admin());
create policy admin_chot on chot_luong for all using (la_admin()) with check (la_admin());
create policy admin_xuat on xuat_thang for all using (la_admin()) with check (la_admin());
create policy admin_cai_dat on cai_dat for all using (la_admin()) with check (la_admin());
create policy admin_ma_qr on ma_qr for all using (la_admin()) with check (la_admin());

create or replace function don_dep_cu() returns int
language plpgsql security definer set search_path = public as $$
declare
  v_n int;
  v_han date := (date_trunc('month', now() at time zone 'Asia/Ho_Chi_Minh')
                 - make_interval(months => (select gia_tri::int from cai_dat where khoa = 'giu_thang') - 1))::date;
begin
  delete from cham_cong c using xuat_thang x
  where x.da_xuat and x.thang = date_trunc('month', c.ngay)::date and c.ngay < v_han;
  get diagnostics v_n = row_count;
  return v_n;
end $$;
revoke execute on function don_dep_cu() from public;
