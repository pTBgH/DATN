<?php

namespace App\Workflow;

use App\Workflow\Nodes\SendEmailNode;
// use App\Workflow\Nodes\CreateInterviewNode;

class NodeRegistry
{
    // 1. Khai báo bản đồ: 'Tên loại node' => 'Tên Class'
    protected array $nodeMap = [
        'action.send_email' => SendEmailNode::class,
        'action.wait'       => \App\Workflow\Nodes\WaitNode::class,
        // 'action.schedule_interview' => CreateInterviewNode::class,
    ];

    public function __construct()
    {
        // 2. XÓA BỎ dòng này đi (Dòng gây lỗi)
        // $this->register(new SendEmailNode()); 
    }

    public function get(string $type)
    {
        // 3. Kiểm tra xem loại node có trong bản đồ không
        if (!isset($this->nodeMap[$type])) {
            return null;
        }

        // 4. Dùng app() để Laravel tự động khởi tạo và tự động bơm KafkaHelper vào
        return app($this->nodeMap[$type]);
    }

    // (Tùy chọn) Giữ lại nếu bạn muốn đăng ký động từ bên ngoài, nhưng hiện tại chưa cần
    public function register($node)
    {
        // $this->nodes[$node->getType()] = $node;
    }

    public function getDefinitions(): array
    {
        return [
            'triggers' => [
                [
                    'type' => 'trigger.stage_entry',
                    'label' => 'Ứng viên vào Vòng (Stage Entry)',
                    'description' => 'Kích hoạt khi ứng viên được di chuyển vào một vòng cụ thể.',
                    'inputs' => [], // Trigger không có input từ node trước
                    'outputs' => ['main'],
                    'parameters' => [
                        [
                            'name' => 'stage_id',
                            'label' => 'Chọn vòng tuyển dụng',
                            'type' => 'select', // FE sẽ gọi API lấy list stage để điền vào đây
                            'required' => true
                        ]
                    ]
                ],
                [
                    'type' => 'trigger.app_created',
                    'label' => 'Ứng viên mới nộp đơn',
                    'description' => 'Kích hoạt khi có đơn ứng tuyển mới.',
                    'inputs' => [],
                    'outputs' => ['main'],
                    'parameters' => []
                ]
            ],
            'actions' => [
                [
                    'type' => 'action.send_email',
                    'label' => 'Gửi Email',
                    'description' => 'Gửi email tự động qua Communication Service.',
                    'inputs' => ['main'],
                    'outputs' => ['main'],
                    'parameters' => [
                        [
                            'name' => 'to',
                            'label' => 'Người nhận',
                            'type' => 'string',
                            'default' => '{{ candidate_email }}', // Gợi ý mặc định
                            'required' => true
                        ],
                        [
                            'name' => 'template',
                            'label' => 'Mẫu Email',
                            'type' => 'select',
                            'options' => [
                                ['value' => 'emails.default', 'label' => 'Mặc định'],
                                ['value' => 'emails.interview_invite', 'label' => 'Mời phỏng vấn'],
                                ['value' => 'emails.rejection', 'label' => 'Thư từ chối'],
                                ['value' => 'emails.offer', 'label' => 'Thư mời nhận việc'],
                            ],
                            'required' => true
                        ],
                        // Ví dụ thêm biến tùy chỉnh để FE hiển thị gợi ý
                        [
                            'name' => 'variables_hint',
                            'type' => 'info',
                            'content' => 'Các biến hỗ trợ: {{ candidate_name }}, {{ job_title }}, {{ company_name }}'
                        ],
                        [
                            'name' => 'duration',
                            'label' => 'Thời gian chờ',
                            'type' => 'number',
                            'suffix' => 'Giờ' // Hoặc làm dropdown chọn phút/giờ/ngày
                        ]
                    ]
                ]
            ]
        ];
    }

}