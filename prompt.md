Đọc AGENTS.md, fix hoàn toàn luồng Google OAuth cho Flutter Web
mà không dùng port cố định:

1. Trong auth_service.dart, đổi signInWithGoogle():
   - Dùng signInWithOAuth với redirectTo: null
   - Thêm authScreenLaunchMode: LaunchMode.inAppWebView 
     hoặc dùng signInWithOAuth không có redirectTo

2. Trong Supabase Dashboard cần set:
   - Site URL: http://localhost
   - Redirect URLs: http://localhost:*

3. Fix GoRouter trong router.dart:
   - Route '/' phải check Supabase session hiện tại
   - Nếu có session → fetch role → navigate đúng
   - Nếu không → /login
   - Xử lý được URL dạng /?code=xxx (OAuth callback)
   - Thêm refreshListenable theo Supabase auth state

4. Trong main.dart:
   - Supabase.initialize() phải chạy trước GoRouter
   - Lắng nghe onAuthStateChange để refresh router