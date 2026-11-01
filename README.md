# Hệ thống quản lý chấm công nhân viên bằng mã QR

> **Lưu ý:** đây là bản demo. Dữ liệu chỉ nằm trong trình duyệt đang dùng, không đồng bộ giữa các máy. Giao diện chưa nối với Supabase, và `database/schema.sql` chưa có mức lương theo lớp, ngày nghỉ chung, lịch phát sinh, đề xuất chỉnh sửa. Vì vậy chưa dùng được cho chấm công thật.

Hệ thống chấm công cho trung tâm nhỏ, thay cho chấm công giấy. Giáo viên đăng nhập một lần, sau đó mỗi buổi chỉ cần quét mã QR chung, không điền gì.

## Tính năng
- **Giáo viên:** quét mã QR để chấm công, xem lịch tháng, xác nhận bù khi quên quét, báo nghỉ phép hoặc báo bận, đề xuất chỉnh sửa lớp và ca dạy của mình để admin duyệt, nhận thông báo thường khi đề xuất hoặc đơn nghỉ được duyệt hay không được duyệt, tự đổi số điện thoại (bắt buộc), mật khẩu, ảnh đại diện và ảnh bìa. Giáo viên không xem được lương.
- **Admin:** theo dõi chấm công trong ngày, quản lý giáo viên, lịch ca và mã QR. Tab Lịch ca có lịch tháng của cả trung tâm, bấm vào một ngày để xem từng ca có giáo viên nào dạy lớp nào. Tab Thông báo gồm hai phần riêng là Đề xuất chỉnh sửa và Duyệt đơn, mỗi phần có Chờ duyệt, Đã duyệt, Từ chối. Khi duyệt đề xuất có bảng so sánh trước và sau.
- **Lương:** mỗi giáo viên, mỗi lớp một mức đ/ca. Sửa mức ngay trong dòng của giáo viên, cùng với thưởng phạt. Có chốt tháng, tháng đã chốt giữ nguyên số cũ.
- **Lịch:** lịch dạy cố định theo tuần, thêm ngày nghỉ chung (Tết, lễ), và đổi lịch một ngày cho trường hợp nghỉ, dạy thay, dạy bù.
- **Giao diện:** mỗi người tự chọn màu riêng, lưu trên thiết bị của họ. Trang đăng nhập giữ màu của lần dùng gần nhất trên thiết bị đó. Ảnh đại diện và ảnh bìa hiện lưu trong trình duyệt của thiết bị, sẽ chuyển sang lưu trên máy chủ khi nối Supabase.
- **An toàn khi chỉnh sửa:** các màn hình quản lý mặc định chỉ xem. Bấm Chỉnh sửa, sửa xong bấm Lưu thay đổi hoặc Hủy. Xóa và các thao tác nhạy cảm đều hỏi xác nhận.

## Cấu trúc
- `web/index.html`: giao diện, một file duy nhất.
- `database/schema.sql`: cơ sở dữ liệu cho Postgres/Supabase, chưa cập nhật theo các tính năng mới ở trên.
- `.github/workflows/pages.yml`: tự đưa thư mục `web` lên GitHub Pages mỗi lần đẩy lên nhánh `main`.

## Chạy thử
Mở `web/index.html` bằng trình duyệt. Hệ thống bắt đầu trống, không có dữ liệu mẫu.
- Đăng nhập admin: tên đăng nhập `admin`, mật khẩu ban đầu `admin123`. Lần đầu đăng nhập, hệ thống hiện hộp thoại bắt buộc đổi mật khẩu. Trang đăng nhập không có nút vào nhanh và không hiện mật khẩu nào.
- Thêm ca ở tab Lịch ca, thêm giáo viên ở tab Giáo viên. Giáo viên mới có mật khẩu ban đầu `123456` và phải đổi ở lần đăng nhập đầu.
- Chip "Giờ demo" ở góc dưới cho chỉnh giờ giả lập để thử quét mã mà không cần chờ đúng giờ ca. Nút "Đặt lại dữ liệu" xóa hết để làm lại từ đầu.
- Dữ liệu thử được lưu trong chính trình duyệt đó và giữ nguyên khi tải lại trang. Nút "Đặt lại dữ liệu" (có cả ở trang đăng nhập) xóa hết và đưa mật khẩu admin về `admin123`. Nếu quên mật khẩu admin khi đang thử thì bấm nút này.

## Đẩy mã lên GitHub
1. Trên github.com tạo một kho trống (không tích thêm README).
2. Trong thư mục `cham-cong-qr` chạy:
```
git init
git add .
git commit -m "He thong cham cong QR"
git branch -M main
git remote add origin https://github.com/<tên-tài-khoản>/<tên-kho>.git
git push -u origin main
```
3. Vào Settings > Pages > Source, chọn GitHub Actions. Đợi workflow chạy xong, địa chỉ sẽ là `https://<tên-tài-khoản>.github.io/<tên-kho>/`. Không cần mua tên miền.

## Nối Supabase (chưa làm trong giao diện)
Mỗi khách hàng có tài khoản admin riêng, tạo lúc cài đặt với mật khẩu ban đầu riêng và bắt đổi ở lần đăng nhập đầu. Không để mật khẩu mặc định trong mã.
1. Tạo project Supabase miễn phí, chạy `database/schema.sql` trong SQL Editor.
2. Tạo tài khoản admin đầu tiên trong Authentication, rồi chạy: `insert into giao_vien (id, ma, ho_ten, vai_tro) values ('<uuid của user>', 'admin', 'Quản trị', 'admin');`
3. Không đưa khóa `service_role` vào kho mã. Chỉ dùng khóa công khai (anon), dữ liệu được bảo vệ bằng các chính sách trong `schema.sql`.
4. Chốt địa chỉ trước khi in mã QR, vì đổi địa chỉ thì phải in lại.
5. Nếu dùng mã QR đổi mỗi ngày, bật pg_cron và lên lịch `select tao_ma_qr_ngay();` hằng ngày.

## Quy tắc chính
- Mã QR dùng được ở bất kỳ đâu và chỉ hoạt động trong khung giờ ca. Kiểu mã cố định hoặc đổi mỗi ngày, chỉnh trong Cài đặt. Ngày nghỉ chung thì mã không hoạt động và không ai bị tính vắng.
- Mã QR chứa địa chỉ dạng `.../#/quet/<mã>`. Giáo viên quét bằng camera điện thoại, trang mở ra và ghi nhận ngay. Không có nút chấm công thủ công.
- Quét sau khi hết ca xác nhận mọi ca đã kết thúc trong ngày.
- Quên quét: giáo viên tự xác nhận bù trong vài ngày, quá hạn thì admin xác nhận. Tháng đã chốt lương thì không sửa được.
- Giáo viên nghỉ phép, báo bận hoặc đã nghỉ việc thì không bị tính ca trong thời gian đó. Cài đặt cho chọn admin duyệt từng đơn hoặc tự động ghi nhận.
- Lớp và ca dạy: giáo viên gửi đề xuất, chỉ khi admin duyệt thì mới đổi. Lớp mới có mức 0 đ cho đến khi admin đặt mức.
- Lương = tổng (số ca × mức của lớp đó) + thưởng − phạt. Không có phụ cấp.
- Giữ 6 tháng gần nhất; tháng quá hạn chỉ bị xóa khi đã xuất file.
- Admin không xem được mật khẩu. Đặt lại mật khẩu sẽ tạo mật khẩu tạm, giáo viên phải đổi ở lần đăng nhập tới.

## Thư viện
- `qrcode-generator` (MIT) tạo mã QR, được nhúng sẵn trong `web/index.html`.

## Trạng thái
Giao diện đang chạy bằng dữ liệu trong trình duyệt. Chưa nối với database, chưa gửi Zalo hoặc email.
