<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Thông báo ứng tuyển thành công</title>
</head>
<body style="margin: 0; padding: 0; font-family: Helvetica, Arial, sans-serif; background-color: #f4f5f7; -webkit-font-smoothing: antialiased;">
    
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f4f5f7; padding: 40px 0;">
        <tr>
            <td align="center">
                
                <table width="600" cellpadding="0" cellspacing="0" style="background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.05); overflow: hidden; max-width: 600px; width: 100%;">
                    
                    <tr>
                        <td height="6" style="background-color: #667eea;"></td>
                    </tr>

                    <tr>
                        <td style="padding: 40px 40px 20px 40px; text-align: center;">
                            <img src="https://img.icons8.com/fluency/96/checked.png" alt="Success" width="64" height="64" style="display: block; margin: 0 auto;">
                        </td>
                    </tr>

                    <tr>
                        <td style="padding: 0 40px; text-align: center;">
                            <h1 style="margin: 0; color: #1f2937; font-size: 24px; font-weight: 700; line-height: 1.4;">
                                Ứng tuyển thành công!
                            </h1>
                            <p style="margin: 10px 0 0; color: #6b7280; font-size: 16px;">
                                Cảm ơn bạn đã quan tâm đến cơ hội nghề nghiệp này.
                            </p>
                        </td>
                    </tr>

                    <tr>
                        <td style="padding: 30px 40px;">
                            
                            <div style="background-color: #f9fafb; border: 1px solid #e5e7eb; border-radius: 6px; padding: 20px;">
                                <p style="margin: 0 0 10px; font-size: 15px; color: #374151;">
                                    Xin chào <strong>{{ $candidate_name }}</strong>,
                                </p>
                                <p style="margin: 0; font-size: 15px; color: #374151; line-height: 1.6;">
                                    Hồ sơ của bạn đã được gửi đến nhà tuyển dụng cho vị trí:
                                </p>
                                <div style="margin-top: 15px; padding-top: 15px; border-top: 1px dashed #d1d5db;">
                                    <p style="margin: 0; font-size: 18px; font-weight: 600; color: #667eea;">
                                        {{ $job_title }}
                                    </p>
                                    <p style="margin: 5px 0 0; font-size: 14px; color: #6b7280; font-weight: 500;">
                                        🏢 {{ $company_name }}
                                    </p>
                                </div>
                            </div>

                            <div style="margin-top: 35px;">
                                <h3 style="margin: 0 0 20px; font-size: 16px; color: #111827; border-bottom: 2px solid #f3f4f6; padding-bottom: 10px; display: inline-block;">
                                    Quy trình tiếp theo
                                </h3>
                                
                                <table width="100%" cellpadding="0" cellspacing="0">
                                    <tr>
                                        <td width="24" valign="top" style="padding-bottom: 20px;">
                                            <div style="width: 24px; height: 24px; background-color: #e0e7ff; color: #667eea; border-radius: 50%; text-align: center; line-height: 24px; font-size: 12px; font-weight: bold;">1</div>
                                        </td>
                                        <td style="padding-left: 15px; padding-bottom: 20px;">
                                            <strong style="font-size: 14px; color: #374151;">Sàng lọc hồ sơ</strong>
                                            <div style="font-size: 13px; color: #6b7280; margin-top: 4px;">Nhà tuyển dụng sẽ xem xét năng lực và kinh nghiệm của bạn.</div>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td width="24" valign="top" style="padding-bottom: 20px;">
                                            <div style="width: 24px; height: 24px; background-color: #e0e7ff; color: #667eea; border-radius: 50%; text-align: center; line-height: 24px; font-size: 12px; font-weight: bold;">2</div>
                                        </td>
                                        <td style="padding-left: 15px; padding-bottom: 20px;">
                                            <strong style="font-size: 14px; color: #374151;">Phỏng vấn</strong>
                                            <div style="font-size: 13px; color: #6b7280; margin-top: 4px;">Ứng viên phù hợp sẽ nhận được email hoặc cuộc gọi mời phỏng vấn.</div>
                                        </td>
                                    </tr>
                                    <tr>
                                        <td width="24" valign="top">
                                            <div style="width: 24px; height: 24px; background-color: #e0e7ff; color: #667eea; border-radius: 50%; text-align: center; line-height: 24px; font-size: 12px; font-weight: bold;">3</div>
                                        </td>
                                        <td style="padding-left: 15px;">
                                            <strong style="font-size: 14px; color: #374151;">Thông báo kết quả</strong>
                                            <div style="font-size: 13px; color: #6b7280; margin-top: 4px;">Hệ thống sẽ cập nhật trạng thái ngay khi có kết quả mới.</div>
                                        </td>
                                    </tr>
                                </table>
                            </div>

                            <div style="margin-top: 40px; text-align: center;">
                                <a href="{{ config('app.frontend_url') }}/my-applications" style="background-color: #667eea; color: #ffffff; padding: 14px 30px; border-radius: 6px; text-decoration: none; font-weight: 600; font-size: 15px; display: inline-block; box-shadow: 0 4px 6px rgba(102, 126, 234, 0.25);">
                                    Theo dõi trạng thái hồ sơ
                                </a>
                            </div>
                            
                            <div style="height: 1px; background-color: #e5e7eb; margin: 40px 0 20px;"></div>

                            <p style="margin: 0; font-size: 14px; color: #9ca3af; text-align: center;">
                                Job7189 Team
                            </p>

                        </td>
                    </tr>
                    
                    <tr>
                        <td style="background-color: #f9fafb; padding: 20px; text-align: center; border-top: 1px solid #e5e7eb;">
                            <p style="margin: 0; font-size: 12px; color: #9ca3af; line-height: 1.5;">
                                Bạn nhận được email này vì đã ứng tuyển trên hệ thống Job7189.<br>
                                Nếu cần hỗ trợ, vui lòng phản hồi lại email này.
                            </p>
                        </td>
                    </tr>

                </table>
                
                <p style="margin-top: 20px; font-size: 12px; color: #9ca3af;">
                    &copy; 2026 Job7189. All rights reserved.
                </p>

            </td>
        </tr>
    </table>
</body>
</html>