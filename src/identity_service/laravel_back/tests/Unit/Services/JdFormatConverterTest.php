<?php
// file: tests/Unit/Services/JdFormatConverterTest.php

namespace Tests\Unit\Services;

use App\Services\Concerns\ConvertsJdFormat;
use PHPUnit\Framework\TestCase;

class JdFormatConverterTest extends TestCase
{
    /**
     * @var object Một đối tượng sử dụng Trait để chúng ta có thể gọi các phương thức.
     */
    private $converter;

    /**
     * Phương thức này chạy trước mỗi test.
     */
    protected function setUp(): void
    {
        parent::setUp();
        // Tạo một class ẩn danh (anonymous class) sử dụng Trait của chúng ta
        $this->converter = new class {
            use ConvertsJdFormat;

            // Expose các phương thức protected để có thể gọi từ bên ngoài trong test
            public function testConvertHtmlToJson(string $html): array
            {
                return $this->convertHtmlToJson($html);
            }

            public function testConvertJsonToHtml($data): string
            {
                return $this->convertJsonToHtml($data);
            }
        };
    }

    // ========== TESTS FOR JSON -> HTML ==========

    public function test_it_converts_simple_array_to_html_unordered_list(): void
    {
        $json = ['Health insurance', 'Paid leave', 'Annual bonus'];
        $expectedHtml = '<ul><li>Health insurance</li><li>Paid leave</li><li>Annual bonus</li></ul>';

        $this->assertEquals($expectedHtml, $this->converter->testConvertJsonToHtml($json));
    }

    public function test_it_converts_associative_array_to_html_list_with_strong_tags(): void
    {
        $json = [
            "Degree" => "Bachelor in Computer Science",
            "TechnicalSkills" => ["Java", "Spring Boot", "SQL"]
        ];
        $expectedHtml = '<ul><li><strong>Degree:</strong> Bachelor in Computer Science</li><li><strong>Technical Skills:</strong> Java, Spring Boot, SQL</li></ul>';

        $this->assertEquals($expectedHtml, $this->converter->testConvertJsonToHtml($json));
    }

    public function test_it_converts_a_string_to_html_paragraph(): void
    {
        $json = "We are looking for a Software Engineer.\nJoin our team!";
        $expectedHtml = '<p>We are looking for a Software Engineer.<br />' . "\n" . 'Join our team!</p>';

        $this->assertEquals($expectedHtml, $this->converter->testConvertJsonToHtml($json));
    }

    // ========== TESTS FOR HTML -> JSON ==========

    public function test_it_converts_html_unordered_list_to_simple_array(): void
    {
        $html = '<ul><li>  Health insurance  </li><li>Paid leave</li> <li>Annual bonus</li></ul>';
        $expectedJson = ['Health insurance', 'Paid leave', 'Annual bonus'];
        
        $this->assertEquals($expectedJson, $this->converter->testConvertHtmlToJson($html));
    }

    public function test_it_converts_html_paragraph_to_array_with_one_element(): void
    {
        $html = '<p>This is a description.<br>With a line break.</p>';
        $expectedJson = ['This is a description. With a line break.'];

        $this->assertEquals($expectedJson, $this->converter->testConvertHtmlToJson($html));
    }
    
    public function test_it_handles_complex_html_within_list_items(): void
    {
        $html = '<ul><li><strong>Yêu cầu:</strong> Tốt nghiệp Đại học</li></ul>';
        $expectedJson = ['Yêu cầu: Tốt nghiệp Đại học'];
        
        $this->assertEquals($expectedJson, $this->converter->testConvertHtmlToJson($html));
    }

        // ========== EXTRA TEST CASES ==========

    public function test_it_converts_empty_html_to_empty_array(): void
    {
        $html = '';
        $expectedJson = [];

        $this->assertEquals($expectedJson, $this->converter->testConvertHtmlToJson($html));
    }

    public function test_it_converts_empty_array_to_empty_html(): void
    {
        $json = [];
        $expectedHtml = '';

        $this->assertEquals($expectedHtml, $this->converter->testConvertJsonToHtml($json));
    }

    public function test_it_converts_nested_html_list_to_nested_array(): void
    {
        $html = '<ul><li>Main</li><li><ul><li>Sub1</li><li>Sub2</li></ul></li></ul>';
        // Hiện tại implement của bạn không hỗ trợ nested list → có thể flatten về dạng ["Main", "Sub1", "Sub2"]
        $expectedJson = ['Main', 'Sub1', 'Sub2'];

        $this->assertEquals($expectedJson, $this->converter->testConvertHtmlToJson($html));
    }

    public function test_it_preserves_special_characters_in_json_to_html(): void
    {
        $json = ['C&C', 'AT&T', '<script>alert("xss")</script>'];
        $expectedHtml = '<ul><li>C&amp;C</li><li>AT&amp;T</li><li>&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;</li></ul>';

        $this->assertEquals($expectedHtml, $this->converter->testConvertJsonToHtml($json));
    }

    public function test_it_round_trips_json_to_html_and_back(): void
    {
        $originalJson = ['Health insurance', 'Paid leave'];
        $html = $this->converter->testConvertJsonToHtml($originalJson);
        $convertedBack = $this->converter->testConvertHtmlToJson($html);

        $this->assertEquals($originalJson, $convertedBack);
    }

    public function test_it_round_trips_paragraph_string_json_to_html_and_back(): void
    {
        $originalJson = "Line one\nLine two";
        $html = $this->converter->testConvertJsonToHtml($originalJson);
        $convertedBack = $this->converter->testConvertHtmlToJson($html);

        // JSON → HTML → JSON có thể làm mất newline, chỉ còn dấu cách
        $expectedJson = ['Line one Line two'];

        $this->assertEquals($expectedJson, $convertedBack);
    }

}