<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cập nhật trạng thái ứng tuyển</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f5f7fa;">
    <!-- Email Wrapper -->
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f5f7fa; padding: 40px 20px;">
        <tr>
            <td align="center">
                <!-- Main Container -->
                <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 12px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); overflow: hidden;">
                    
                    <!-- Header -->
                    <tr>
                        <td style="background: linear-gradient(135deg, #2196F3 0%, #1976D2 100%); padding: 40px 30px; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 600; letter-spacing: -0.5px;">
                                📬 Cập nhật hồ sơ ứng tuyển
                            </h1>
                        </td>
                    </tr>

                    <!-- Content -->
                    <tr>
                        <td style="padding: 50px 40px;">
                            <!-- Greeting -->
                            <p style="margin: 0 0 25px; font-size: 18px; color: #1a202c; font-weight: 500;">
                                Xin chào <span style="color: #2196F3;">{{ $candidate_name }}</span>,
                            </p>

                            <!-- Main Update Message -->
                            <div style="background: linear-gradient(135deg, #e3f2fd 0%, #bbdefb 100%); border-radius: 12px; padding: 30px; margin: 30px 0; text-align: center;">
                                <p style="margin: 0 0 15px; font-size: 15px; color: #1565c0; text-transform: uppercase; letter-spacing: 1px; font-weight: 600;">
                                    Trạng thái mới
                                </p>
                                <div style="background-color: #ffffff; display: inline-block; padding: 15px 30px; border-radius: 25px; box-shadow: 0 4px 12px rgba(33, 150, 243, 0.2);">
                                    <p style="margin: 0; font-size: 24px; color: #2196F3; font-weight: 700;">
                                        ✨ {{ $new_stage_name }}
                                    </p>
                                </div>
                            </div>

                            <!-- Job Info -->
                            <div style="background-color: #f7fafc; border-left: 4px solid #2196F3; padding: 20px 25px; margin: 30px 0; border-radius: 6px;">
                                <p style="margin: 0 0 8px; font-size: 14px; color: #718096; text-transform: uppercase; letter-spacing: 0.5px;">
                                    Vị trí ứng tuyển
                                </p>
                                <h2 style="margin: 0 0 8px; font-size: 20px; color: #1a202c; font-weight: 600;">
                                    {{ $job_title }}
                                </h2>
                                <p style="margin: 0; font-size: 15px; color: #718096;">
                                    tại <strong>{{ $company_name }}</strong>
                                </p>
                            </div>

                            <!-- Status-specific messages -->
                            <div style="margin: 35px 0;">
                                <h3 style="margin: 0 0 20px; font-size: 16px; color: #4a5568; font-weight: 600;">
                                    🎯 Điều này có nghĩa là gì?
                                </h3>
                                
                                <div style="background-color: #f0f9ff; border: 1px solid #bae6fd; border-radius: 8px; padding: 20px;">
                                    <p style="margin: 0; font-size: 15px; color: #0c4a6e; line-height: 1.7;">
                                        Hồ sơ của bạn đã được cập nhật sang giai đoạn <strong style="color: #2196F3;">{{ $new_stage_name }}</strong>. 
                                        Nhà tuyển dụng đang quan tâm đến ứng viên của bạn và sẽ liên hệ với bạn trong thời gian sớm nhất nếu cần thêm thông tin.
                                    </p>
                                </div>
                            </div>

                            <!-- What's Next Section -->
                            <div style="margin: 35px 0;">
                                <h3 style="margin: 0 0 20px; font-size: 16px; color: #4a5568; font-weight: 600;">
                                    📌 Bạn nên làm gì tiếp theo?
                                </h3>
                                
                                <table width="100%" cellpadding="0" cellspacing="0">
                                    <tr>
                                        <td style="padding: 12px 0;">
                                            <div style="display: flex; align-items: start;">
                                                <span style="color: #2196F3; font-size: 20px; margin-right: 12px;">✓</span>
                                                <p style="margin: 0; color: #2d3748; font-size: 15px; line-height: 1.6;">Kiểm tra email và điện thoại thường xuyên để không bỏ lỡ thông tin quan trọng</p>
                                            </div>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td style="padding: 12px 0;">
                                            <div style="display: flex; align-items: start;">
                                                <span style="color: #2196F3; font-size: 20px; margin-right: 12px;">✓</span>
                                                <p style="margin: 0; color: #2d3748; font-size: 15px; line-height: 1.6;">Nghiên cứu thêm về công ty và vị trí công việc để chuẩn bị tốt hơn</p>
                                            </div>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td style="padding: 12px 0;">
                                            <div style="display: flex; align-items: start;">
                                                <span style="color: #2196F3; font-size: 20px; margin-right: 12px;">✓</span>
                                                <p style="margin: 0; color: #2d3748; font-size: 15px; line-height: 1.6;">Theo dõi tiến trình ứng tuyển qua dashboard của bạn</p>
                                            </div>
                                        </td>
                                    </tr>
                                </table>
                            </div>

                            <!-- CTA Button -->
                            <table width="100%" cellpadding="0" cellspacing="0" style="margin: 35px 0;">
                                <tr>
                                    <td align="center">
                                        <a href="{{ config('app.frontend_url') }}/my-applications" 
                                           style="display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, #2196F3 0%, #1976D2 100%); color: #ffffff; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px; box-shadow: 0 4px 12px rgba(33, 150, 243, 0.4);">
                                            📊 Xem chi tiết tiến trình
                                        </a>
                                    </td>
                                </tr>
                            </table>

                            <!-- Encouragement Box -->
                            <div style="background-color: #ecfdf5; border: 1px solid #6ee7b7; border-radius: 8px; padding: 20px; margin: 30px 0; text-align: center;">
                                <p style="margin: 0; font-size: 16px; color: #065f46; font-weight: 600;">
                                    🌟 Tiếp tục giữ vững phong độ!
                                </p>
                                <p style="margin: 10px 0 0; font-size: 14px; color: #065f46; line-height: 1.6;">
                                    Bạn đang trên con đường đúng đắn. Chúng tôi tin rằng cơ hội tuyệt vời đang chờ đợi bạn phía trước!
                                </p>
                            </div>

                            <!-- Closing -->
                            <p style="margin: 30px 0 10px; font-size: 16px; color: #2d3748; line-height: 1.6;">
                                Chúc bạn thành công! 💼
                            </p>
                            <p style="margin: 0; font-size: 16px; color: #2d3748;">
                                <strong>Đội ngũ Job7189</strong>
                            </p>
                        </td>
                    </tr>

                    <!-- Footer -->
                    <tr>
                        <td style="background-color: #f7fafc; padding: 30px 40px; border-top: 1px solid #e2e8f0;">
                            <table width="100%" cellpadding="0" cellspacing="0">
                                <tr>
                                    <td align="center">
                                        <p style="margin: 0 0 15px; font-size: 13px; color: #718096;">
                                            Email này được gửi tự động từ hệ thống Job7189
                                        </p>
                                        <p style="margin: 0 0 15px; font-size: 13px; color: #718096;">
                                            Có thắc mắc? Liên hệ: 
                                            <a href="mailto:support@job7189.com" style="color: #2196F3; text-decoration: none;">support@job7189.com</a>
                                        </p>
                                        
                                        <!-- Social Links -->
                                        <div style="margin-top: 20px;">
                                            <a href="#" style="display: inline-block; margin: 0 8px;">
                                                <img src="https://img.icons8.com/fluency/48/facebook-new.png" alt="Facebook" width="32" height="32" style="border-radius: 50%;">
                                            </a>
                                            <a href="#" style="display: inline-block; margin: 0 8px;">
                                                <img src="https://img.icons8.com/fluency/48/linkedin.png" alt="LinkedIn" width="32" height="32" style="border-radius: 50%;">
                                            </a>
                                            <a href="#" style="display: inline-block; margin: 0 8px;">
                                                <img src="https://img.icons8.com/fluency/48/twitter.png" alt="Twitter" width="32" height="32" style="border-radius: 50%;">
                                            </a>
                                        </div>

                                        <p style="margin: 20px 0 0; font-size: 12px; color: #a0aec0;">
                                            © 2026 Job7189. All rights reserved.
                                        </p>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>

                </table>
            </td>
        </tr>
    </table>
</body>
</html>