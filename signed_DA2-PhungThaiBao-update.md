|          | ĐẠI                | HỌC    | BÁCH         | KHOA HÀ       | NỘI         |      |
| -------- | ------------------ | ------ | ------------ | ------------- | ----------- | ---- |
|          |                    | KHOA   | TOÁN         | - TIN         |             |      |
|          | Kiến               | trúc   | Microservice |               | và          |      |
| Ứng dụng | trong              | Xây    | dựng         | Hệ thống      | tuyển       | dụng |
|          |                    |        | ĐỒ ÁN        | II            |             |      |
|          | Chuyên             | ngành: | Hệ thống     | thông         | tin quản lý |      |
|          | Giảngviênhướngdẫn: |        |              | TS.VũThànhNam |             |      |
|          | Sinhviênthựchiện:  |        |              | PhùngTháiBảo  |             |      |
|          | Mãsốsinhviên:      |        |              | 20227189      |             |      |
|          |                    | HÀ     | NỘI,         | 01/2026       |             |      |

Lời cảm ơn
Lời đầu tiên, em xin gửi lời cảm ơn chân thành và sâu sắc nhất tới TS. Vũ Thành Nam,
người đã trực tiếp hướng dẫn, chỉ bảo tận tình và đồng hành cùng em trong suốt quá trình
thực hiện Đồ án II. Những định hướng chuyên môn quý báu, sự khắt khe về mặt kỹ thuật
cũng như những lời động viên của thầy đã giúp em vượt qua nhiều khó khăn để hoàn thiện
hệthốngvànângcaotưduyvềkiếntrúcphầnmềm.
Em cũng xin bày tỏ lòng biết ơn chân thành tới các thầy, cô giáo tại Đại học Bách Khoa
Hà Nội nói chung, và các thầy cô thuộc Khoa Toán - Tin nói riêng. Trong suốt những năm
họctậptạitrường,cácthầycôđãtruyềnđạtchoemnhữngkiếnthứcnềntảngvữngchắc,tạo
điều kiện môi trường học tập chuyên nghiệp để em có đủ kỹ năng cũng như phương pháp tư
duyđểthựchiệnđềtàinày.
Mặcdùđãdànhnhiềutâmhuyếtvànỗlựcđểthựchiệnđềtài,nhưngdogiớihạnvềthời
giancũngnhưkinhnghiệmthựctiễn,đồánchắcchắnkhôngtránhkhỏinhữngthiếusót.Em
rất mong nhận được những ý kiến đóng góp và chỉ dẫn của các thầy cô để đề tài được hoàn
thiệnhơnvàcóthểứngdụnghiệuquảtrongtươnglai.
Emxinchânthànhcảmơn!
HàNội,tháng01năm2026
Sinhviênthựchiện
PhùngTháiBảo
i

Tóm tắt đồ án
Đồán"KiếntrúcMicroservicevàỨngdụngtrongXâydựngHệthốngtuyểndụng"
nghiêncứuvàhiệnthựchóamộtkhungkiếntrúcphântánhiệnđạinhằmnângcaokhảnăng
mở rộng, tính linh hoạt và độ tin cậy của hệ thống phần mềm doanh nghiệp, khắc phục các
hạnchếcủakiếntrúcđơnkhốitruyềnthống.
Trên cơ sở phương pháp Domain-Driven Design (DDD), nghiệp vụ tuyển dụng được
phânrãthành07Microservicesđộclập:Identity,Workspace,Job,Hiring,Candidate,Storage
và Communication, mỗi dịch vụ sở hữu ranh giới nghiệp vụ rõ ràng, cơ sở dữ liệu riêng và
sử dụng định danh toàn cục UUIDv7. Hệ thống được triển khai với các công nghệ chủ đạo
gồm Kong API Gateway, Keycloak, Apache Kafka, MinIO và ELK Stack, hỗ trợ kiến trúc
Event-Driven,bảomật,lưutrữtệpvàgiámsáttậptrung.
Kết quảthực nghiệmcho thấyhệ thốngđáp ứnghiệu quảcác quy trìnhnghiệp vụcốt lõi
của bài toán tuyển dụng như đăng tuyển, ứng tuyển và quản lý ứng viên theo mô hình ATS,
đồng thời hình thành một nền tảng kiến trúc vững chắc, cho phép mở rộng và phát triển hệ
thốngtrongtươnglai.
Từ khóa: Microservices, Domain-Driven Design, Apache Kafka, API Gateway, ATS,
UUIDv7,Event-DrivenArchitecture.
ii

| NHẬN   | XÉT         | CỦA  | GIẢNG  | VIÊN HƯỚNG |     | DẪN |
| ------ | ----------- | ---- | ------ | ---------- | --- | --- |
| 1. Mục | tiêu và nội | dung | của đồ | án         |     |     |
(a) Mục tiêu: ....................................................
................................................................
................................................................
(b) Nội dung: ....................................................
................................................................
................................................................
................................................................
| 2. Kết | quả đạt được: |     |     |     |     |     |
| ------ | ------------- | --- | --- | --- | --- | --- |
................................................................
................................................................
................................................................
................................................................
| 3. Ý thức | làm việc | của | sinh viên: |     |     |     |
| --------- | -------- | --- | ---------- | --- | --- | --- |
................................................................
................................................................
................................................................
................................................................
|     |     |     |     | HàNội,ngày | tháng | năm2026 |
| --- | --- | --- | --- | ---------- | ----- | ------- |
Giảngviênhướngdẫn

Mục lục
Lờicảmơn i
Tómtắtđồán ii
1 TổngquanvàCơsởlýthuyết 1
1.1 Tổngquannghiêncứu . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 1
1.1.1 Bốicảnhvànhucầuthựctiễn . . . . . . . . . . . . . . . . . . . . 1
1.1.2 Mụctiêuvàphạmvinghiêncứu . . . . . . . . . . . . . . . . . . . 1
1.2 TổngquanvềkiếntrúcMicroservice . . . . . . . . . . . . . . . . . . . . . 2
1.2.1 ĐịnhnghĩavàTriếtlý . . . . . . . . . . . . . . . . . . . . . . . . 2
1.2.2 Môhìnhtrưởngthành3lớp . . . . . . . . . . . . . . . . . . . . . 2
1.2.3 CácđặctrưngcốtlõicủaMicroservice . . . . . . . . . . . . . . . 2
1.2.4 SosánhvớikiếntrúcMonolithic . . . . . . . . . . . . . . . . . . . 3
1.3 Phươngphápmôhìnhhóahệthống(C4Model) . . . . . . . . . . . . . . . 3
1.3.1 GiớithiệuvềC4Model . . . . . . . . . . . . . . . . . . . . . . . . 3
1.3.2 LýdolựachọnC4ModelchoMicroservice . . . . . . . . . . . . . 4
1.4 Cáccôngnghệsửdụng . . . . . . . . . . . . . . . . . . . . . . . . . . . . 4
1.4.1 NềntảngđiềuphốiContainer–Kubernetes . . . . . . . . . . . . . 4
1.4.2 QuảnlýcấuhìnhtriểnkhaivớiHelmvàHelmfile . . . . . . . . . . 4
1.4.3 Hệquảntrịcơsởdữliệu–MySQL . . . . . . . . . . . . . . . . . 5
1.4.4 Nềntảngpháttriểndịchvụnghiệpvụ–Laravel . . . . . . . . . . . 5
1.4.5 Hạtầnggửithưđiệntử–GoogleSMTP . . . . . . . . . . . . . . . 5
2 PhươngphápphântíchvàthiếtkếkiếntrúcMicroservice 7
2.1 Thiếtkếhướngmiền . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 7
2.1.1 GiớithiệuvềThiếtkếhướngmiền . . . . . . . . . . . . . . . . . . 7
2.1.2 TínhcầnthiếtcủaDDDtrongkiếntrúcMicroservices . . . . . . . 7
2.1.3 ThiếtkếChiếnlược(StrategicDesign) . . . . . . . . . . . . . . . . 8
2.1.4 ThiếtkếChiếnthuật(TacticalDesign) . . . . . . . . . . . . . . . . 10
2.1.5 Kiếntrúchệthống-VỏbọcbảovệDomain . . . . . . . . . . . . . 10
v

2.1.6 GiaotiếpvàTínhnhấtquándữliệuphântán . . . . . . . . . . . . 11
2.1.7 CaseStudy:PhântíchOnlineBoutiquevớiDDD . . . . . . . . . . 11
2.1.8 Kếtluận . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 11
2.2 Cácmẫuthiếtkếgiaotiếpvàtíchhợp . . . . . . . . . . . . . . . . . . . . 11
2.2.1 Giaotiếpđồngbộ(SynchronousCommunication) . . . . . . . . . 12
2.2.2 GiaotiếpbấtđồngbộvàKiếntrúchướngsựkiện . . . . . . . . . . 12
2.2.3 ThiếtkếAPIGatewayvàBackendforFrontend(BFF) . . . . . . . 13
2.3 Quảnlýdữliệuvàtínhnhấtquán . . . . . . . . . . . . . . . . . . . . . . . 13
2.3.1 Tínhnhấtquáncuốicùng . . . . . . . . . . . . . . . . . . . . . . . 14
2.3.2 MẫuCQRS(CommandQueryResponsibilitySegregation) . . . . . 14
2.3.3 MẫuSaga(Quảnlýgiaodịchphântán) . . . . . . . . . . . . . . . 14
2.3.4 MẫuEventSourcing . . . . . . . . . . . . . . . . . . . . . . . . . 14
2.4 HạtầngvàVậnhành . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 15
2.4.1 CơchếServiceDiscovery(Khámphádịchvụ) . . . . . . . . . . . 15
2.4.2 CơchếLoadBalancing(Cânbằngtải) . . . . . . . . . . . . . . . . 15
2.4.3 GiámsáttậptrungvàObservability(Khảnăngquansát) . . . . . . 15
2.4.4 QuytrìnhtriểnkhaivàvănhóaDevOps . . . . . . . . . . . . . . . 16
2.5 Kếtluậnchương2 . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 16
3 XâydựnghệthốngTuyểndụngtrựctuyến 18
3.1 Phântíchyêucầunghiệpvụ . . . . . . . . . . . . . . . . . . . . . . . . . 18
3.1.1 Khảosátvàthuthậpyêucầunghiệpvụ . . . . . . . . . . . . . . . 18
3.1.2 Môhìnhhóaquytrìnhnghiệpvụ(BPMN) . . . . . . . . . . . . . . 19
3.1.3 BiểuđồUseCasevàĐặctảchứcnăng . . . . . . . . . . . . . . . . 21
3.1.4 ĐặctảchitiếtcácUseCasecốtlõi . . . . . . . . . . . . . . . . . . 24
3.1.5 Yêucầuphichứcnăng . . . . . . . . . . . . . . . . . . . . . . . . 27
3.2 Thiếtkếkiếntrúchệthống . . . . . . . . . . . . . . . . . . . . . . . . . . 29
3.2.1 Level1:Sơđồngữcảnhhệthống . . . . . . . . . . . . . . . . . . 29
3.2.2 Level2:ContainerDiagram(SơđồContainer) . . . . . . . . . . . 30
3.2.3 Level2:ContainerDiagram(SơđồContainer) . . . . . . . . . . . 31
3.2.4 Thiếtkếchitiếtcácdịchvụnghiệpvụ(MicroservicesDesign) . . . 33
3.2.5 Level3:ComponentDiagram(SơđồThànhphần) . . . . . . . . . 34
3.2.6 ThiếtkếchitiếthạtầngvàVậnhành . . . . . . . . . . . . . . . . . 42
3.2.7 Thiếtkếmôhìnhtriểnkhai(DeploymentDiagram) . . . . . . . . . 42
3.3 Thiếtkếchitiếtgiaotiếpvàdữliệu . . . . . . . . . . . . . . . . . . . . . . 43
3.3.1 ThiếtkếCơsởdữliệuphântán . . . . . . . . . . . . . . . . . . . 43
3.3.2 Đặctảgiaodiệnlậptrìnhứngdụng(APISpecifications) . . . . . . 46
3.3.3 Biểuđồtuầntựliêndịchvụ(Cross-serviceSequenceDiagram) . . 50

3.3.4 Cấuhìnhhạtầngthựcnghiệm . . . . . . . . . . . . . . . . . . . . 54
3.3.5 KếtquảtriểnkhaiBackend . . . . . . . . . . . . . . . . . . . . . . 54
3.4 Kếtluậnchương3 . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 56
Kếtluận 57

Danh sách hình vẽ
2.1 Từngữ"Sảnphẩm"trongcácBoundedContextkhácnhau . . . . . . . . . . 9
3.1 SơđồQuytrìnhĐăngtuyển . . . . . . . . . . . . . . . . . . . . . . . . . 19
3.2 SơđồQuytrìnhỨngtuyển . . . . . . . . . . . . . . . . . . . . . . . . . . 21
3.3 BiểuđồUseCasehệthốngtuyểndụng . . . . . . . . . . . . . . . . . . . . 22
3.4 Quyướckýhiệusửdụngtrongcácsơđồcủahệthống . . . . . . . . . . . 29
3.5 SơđồngữcảnhhệthốngcủahệthốngJob7189 . . . . . . . . . . . . . . . 29
3.6 SơđồContainer-Gócnhìnluồngnghiệpvụ . . . . . . . . . . . . . . . . . 31
3.7 Chúgiảikýhiệugócnhìnnghiệpvụ . . . . . . . . . . . . . . . . . . . . . 31
3.8 SơđồContainer-Gócnhìnlưutrữdữliệu . . . . . . . . . . . . . . . . . . 32
3.9 Chúgiảikýhiệugócnhìndữliệu . . . . . . . . . . . . . . . . . . . . . . . 32
3.10 SơđồContainer-Gócnhìngiámsáthệthống . . . . . . . . . . . . . . . . 33
3.11 Chúgiảikýhiệugócnhìngiámsát . . . . . . . . . . . . . . . . . . . . . . 34
3.12 SơđồthànhphầnIdentityService . . . . . . . . . . . . . . . . . . . . . . 35
3.13 SơđồthànhphầnWorkspaceService . . . . . . . . . . . . . . . . . . . . . 36
3.14 SơđồthànhphầnJobService . . . . . . . . . . . . . . . . . . . . . . . . . 37
3.15 SơđồthànhphầnHiringService . . . . . . . . . . . . . . . . . . . . . . . 38
3.16 SơđồthànhphầnCandidateService . . . . . . . . . . . . . . . . . . . . . 39
3.17 SơđồthànhphầnCommunicationService . . . . . . . . . . . . . . . . . . 40
3.18 SơđồthànhphầnStorageService . . . . . . . . . . . . . . . . . . . . . . 41
3.19 Lượcđồcơsởdữliệujob7189_candidate_dbvàjob7189_communication_db 43
3.20 Lượcđồcơsởdữliệujob7189_identity_dbvàjob7189_hiring_db . . . . . 44
3.21 Lượcđồcơsởdữliệujob7189_job_dbvớicấutrúcthôngtinchitiết . . . . 45
3.22 Biểuđồtuầntựluồngtảihồsơứngviên . . . . . . . . . . . . . . . . . . . 53
3.23 Biểuđồtuầntựluồngdichuyểnứngviênquacácvòng . . . . . . . . . . . 54
3.24 CácRoutenghiệpvụđượcđịnhtuyếnquaKongGateway . . . . . . . . . . 55
3.25 KếtquảkiểmthửAPIPhêduyệttinđăng(AdminApprove) . . . . . . . . . 55
3.26 Kếtquảkiểmthửcáctrạngtháikhởitạotintuyểndụng . . . . . . . . . . . 56
viii

Danh sách bảng
1.1 CáclớptiếpcậnMicroservicetheomụctiêu . . . . . . . . . . . . . . . . . 3
1.2 SosánhMicroservicevàMonolithic . . . . . . . . . . . . . . . . . . . . . 3
2.1 PhânloạiMiềncontrongDDD . . . . . . . . . . . . . . . . . . . . . . . . 8
2.2 CácmẫuquanhệchínhtrongContextMapping . . . . . . . . . . . . . . . 9
2.3 SosánhgiaotiếpĐồngbộvàBấtđồngbộ . . . . . . . . . . . . . . . . . . 14
3.1 Đặctảcáctácnhânvàquyềnhạntronghệthống . . . . . . . . . . . . . . . 23
3.2 ĐặctảAPIcủaIdentityService . . . . . . . . . . . . . . . . . . . . . . . 46
3.3 ĐặctảAPIcủaWorkspaceService . . . . . . . . . . . . . . . . . . . . . . 47
3.4 ĐặctảAPIcủaJobService . . . . . . . . . . . . . . . . . . . . . . . . . . 48
3.5 ĐặctảAPIcủaHiringService . . . . . . . . . . . . . . . . . . . . . . . . 49
3.6 ĐặctảAPICandidatevàStorageService . . . . . . . . . . . . . . . . . . . 49
3.7 CáctươngtácđồngbộgiữacácMicroservices . . . . . . . . . . . . . . . . 51
3.8 Danhsáchcácsựkiện(Events)traođổigiữacácdịchvụ . . . . . . . . . . 52
ix

Chương 1
Tổng quan và Cơ sở lý thuyết
1.1 Tổng quan nghiên cứu
1.1.1 Bối cảnh và nhu cầu thực tiễn
Trongquátrìnhpháttriểncủangànhkỹthuậtphầnmềm,kiếntrúcđơnkhối(Monolithic
Architecture) từng là lựa chọn chủ đạo nhờ tính đơn giản trong thiết kế và triển khai. Tuy
nhiên, khi quy mô hệ thống và tổ chức ngày càng mở rộng, mô hình này dần bộc lộ nhiều
hạn chế, đặc biệt về khả năng mở rộng, tốc độ phát hành và khả năng chịu lỗi. Các thay đổi
nhỏtronghệthốngcóthểkéotheoquátrìnhbuildvàdeploytoànbộứngdụng,làmgiatăng
rủirovàgiảmhiệusuấtpháttriển.
Trongbốicảnhđó,kiếntrúcMicroservicexuấthiệnnhưmộthướngtiếpcậntấtyếunhằm
giải quyết “sự mong manh của phần mềm” và đáp ứng yêu cầu phát triển linh hoạt của các
hệthốnghiệnđại.Microservicechophépphântáchhệthốngthànhcácdịchvụnhỏ,độclập,
triển khai linh hoạt trên hạ tầng đám mây, từ đó nâng cao khả năng thích ứng với thay đổi
củathịtrườngvàyêucầukinhdoanh.
1.1.2 Mục tiêu và phạm vi nghiên cứu
Đồántậptrungnghiêncứuphươngphápluậnthiếtkếvàxâydựnghệthốngphântándựa
trênkiếntrúcMicroservice.Cácnộidungnghiêncứuchínhbaogồm:
• PhântíchtriếtlýcânbằnggiữaTốcđộpháttriển,ĐộantoànhệthốngvàKhảnăng
mởrộngtrongkiếntrúcMicroservice.
• Nghiên cứu chiến lược phân rã hệ thống dựa trên miền nghiệp vụ theo phương pháp
Domain-DrivenDesign(DDD).
1

CHƯƠNG1. TỔNGQUANVÀCƠSỞLÝTHUYẾT
• Khảo sát và áp dụng các mẫu thiết kế quản lý dữ liệu phân tán như Saga, CQRS và
EventSourcing.
• ThựcnghiệmcácnguyênlýtrênvàobàitoánHệthốngTuyểndụngtrựctuyếnnhằm
đánhgiátínhkhảthivàhiệuquảthựctiễn.
1.2 Tổng quan về kiến trúc Microservice
1.2.1 Định nghĩa và Triết lý
Định nghĩa: Theo Newman [1, tr. 3], Microservice là phong cách kiến trúc trong đó hệ
thốngđượcxâydựngtừcácdịchvụnhỏ,cókhảnăngtriểnkhaiđộclậpvàđượcmôhìnhhóa
xoay quanh các miền nghiệp vụ cụ thể. Nadareishvili và cộng sự [2, tr. 22] nhấn mạnh thêm
yếu tố tự động hóa khi định nghĩa Microservice là các thành phần triển khai độc lập, giao
tiếpthôngquatruyềnthôngđiệp,hướngtớicáchệthốngcókhảnăngtiếnhóalâudài.
Triết lý cốt lõi: Microservice không đơn thuần là việc chia nhỏ hệ thống mà là quá trình
đạtđượcsựhàihòagiữabayếutốnềntảng:Tốcđộ,AntoànvàQuymô[2,tr.2].
• Tốc độ: Cho phép phát hành nhanh chóng nhờ khả năng triển khai độc lập từng dịch
vụ.
• Antoàn:Côlậplỗi,đảmbảosựcốcủamộtdịchvụkhônglansangtoànhệthống.
• Quy mô: Cho phép mở rộng cục bộ các thành phần chịu tải cao mà không ảnh hưởng
đếntoànbộhệthống.
1.2.2 Mô hình trưởng thành 3 lớp
Tiếp cận Microservice là một quá trình tiến hóa có định hướng kinh doanh, được mô tả
thôngquabalớppháttriểnkếtiếpnhau[2,tr.17–19]:
1.2.3 Các đặc trưng cốt lõi của Microservice
KiếntrúcMicroserviceđượcđặctrưngbởicácthuộctínhsau[2,tr.23]:
• Triểnkhaiđộclập:Mỗidịchvụcóthểbuildvàdeployriêngbiệt.
• Mô hình hóa theo miền nghiệp vụ: Sử dụng Bounded Context để xác định ranh giới
tráchnhiệm.
2

| CHƯƠNG1. | TỔNGQUANVÀCƠSỞLÝTHUYẾT |     |     |     |     |     |
| -------- | ---------------------- | --- | --- | --- | --- | --- |
Bảng1.1:CáclớptiếpcậnMicroservicetheomụctiêu
| Lớp |     | Môtảchính |     | LợiíchTốcđộ |     | LợiíchAntoàn |
| --- | --- | --------- | --- | ----------- | --- | ------------ |
1:Modularized Tách hệ thống thành Triển khai độc lập, Kiểm thử và quản lý
|     |     | các dịch | vụ nhỏ giao | linhhoạtcôngnghệ. |     | côlập. |
| --- | --- | -------- | ----------- | ----------------- | --- | ------ |
tiếpquamạng.
2:Cohesive Định nghĩa ranh giới Teamtựtrịtheomiền, Giảm nợ kỹ thuật, dễ
|     |     | theo miền | nghiệp vụ | táisửdụngcao. |     | thaythếdịchvụ. |
| --- | --- | --------- | --------- | ------------- | --- | -------------- |
(DDD).
3:Systematized Quản lý toàn hệ sinh Khả năng thích ứng Tự động mở rộng,
|     |     | tháiMicroservice. |     | kinhdoanhcao. |     | thiếtkếchothấtbại. |
| --- | --- | ----------------- | --- | ------------- | --- | ------------------ |
• Sở hữu trạng thái riêng: Mỗi dịch vụ quản lý cơ sở dữ liệu riêng, đảm bảo liên kết
lỏng[1,tr.29].
• Tínhtựtrị:Độipháttriểncóquyềnquyếtđịnhcôngnghệvàquytrìnhriêng.
• Độ hạt linh hoạt: Kích thước dịch vụ phụ thuộc vào phạm vi nghiệp vụ chứ không
dựatrênsốdòngmã.
| 1.2.4 | So sánh | với kiến | trúc Monolithic |     |     |     |
| ----- | ------- | -------- | --------------- | --- | --- | --- |
Việc lựa chọn kiến trúc luôn tồn tại sự đánh đổi giữa độ phức tạp phát triển và độ phức
tạp vận hành. Một rủi ro lớn khi áp dụng Microservice là hình thành Distributed Monolith –
hệ thống phân tán nhưng phụ thuộc chặt chẽ, mang nhược điểm của cả hai kiến trúc [1, tr.
43].
Bảng1.2:SosánhMicroservicevàMonolithic
| Tiêuchí   |     | Monolithic               |     |     | Microservice             |     |
| --------- | --- | ------------------------ | --- | --- | ------------------------ | --- |
| Triểnkhai |     | Rủirocao,chậmkhithayđổi. |     |     | Nhanh,độclập,hỗtrợCI/CD. |     |
Quảnlýdữliệu Nhấtquánmạnh(ACID). Nhất quán cuối cùng (Eventual
Consistency).
| Giaotiếp |     | Gọihàmnộibộ,tốcđộcao. |     |     | Gọimạng,cóđộtrễ. |     |
| -------- | --- | --------------------- | --- | --- | ---------------- | --- |
Khảnăngphụchồi SinglePointofFailure. Cô lập lỗi, hỗ trợ Circuit
Breaker.
| 1.3 Phương |            | pháp  | mô hình | hóa hệ | thống | (C4 Model) |
| ---------- | ---------- | ----- | ------- | ------ | ----- | ---------- |
| 1.3.1      | Giới thiệu | về C4 | Model   |        |       |            |
C4 Model là phương pháp mô hình hóa kiến trúc đơn giản và phân cấp, sử dụng ẩn dụ
bản đồ địa lý để thể hiện hệ thống ở các mức độ trừu tượng khác nhau [3]. C4 là viết tắt của
bốncấpđộmôhình:
3

CHƯƠNG1. TỔNGQUANVÀCƠSỞLÝTHUYẾT
• Level1:SystemContext:Cungcấpcáinhìntổngquanvềhệthốngvàcáctácnhân.
• Level2:Containers:Thểhiệncácđơnvịtriểnkhaiđộclập(WebApp,API,Database,
MessageBroker).
• Level3:Components:ĐisâuvàomộtContainerđểthấycácmodulebêntrong.
• Level4:Code:Chitiếttriểnkhaimãnguồn(ERD,ClassDiagram).
1.3.2 Lý do lựa chọn C4 Model cho Microservice
C4 Model đặc biệt phù hợp để trực quan hóa sự phân tán của Microservice. Level 2
(Container) giúp thể hiện rõ ranh giới dữ liệu (Database-per-Service) và các phương thức
giaotiếpđồngbộ/bấtđồngbộgiữacácdịchvụ,điềumàcácbiểuđồUMLtruyềnthốngkhó
thểhiệntườngminh.
1.4 Các công nghệ sử dụng
1.4.1 Nền tảng điều phối Container – Kubernetes
Hệ thống được triển khai trên nền tảng Kubernetes [4] nhằm quản lý vòng đời của các
Microservice một cách tự động và ổn định. Kubernetes cung cấp các cơ chế cốt lõi như
Service Discovery, Load Balancing, Self-healing, Rolling Update và Auto-scaling, giúp hệ
thốngduytrìkhảnăngsẵnsàngcaongaycảkhixảyralỗiởcấpđộcontainerhoặcnode.
Mỗi Microservice trong hệ thống được triển khai dưới dạng Deployment, các dịch vụ
lưu trữ trạng thái (như MySQL) được triển khai dưới dạng StatefulSet kết hợp với Persistent
Volume,đảmbảodữliệukhôngbịmấtkhiPodđượctáitạo.
1.4.2 Quản lý cấu hình triển khai với Helm và Helmfile
Helm[5]đượcsửdụngnhưmộttrìnhquảnlýgóichoKubernetes,chophépmôhìnhhóa
cáccấuhìnhtriểnkhaidướidạngcácChart cókhảnăngtáisửdụngvàthamsốhóa.
Helmfile[6]đóngvaitròlớpđiềuphốiphíatrênHelm,chophépquảnlýđồngthờinhiều
Chart, nhiều môi trường triển khai và nhiều biến cấu hình trong cùng một hệ thống, giúp
giảmthiểulỗicấuhìnhvànângcaokhảnăngtựđộnghóaquytrìnhtriểnkhai.
Sự kết hợp Helm – Helmfile giúp hệ thống đạt được tính nhất quán cấu hình, dễ dàng tái
lậpmôitrườngvàhỗtrợtốtchoCI/CD.
4

CHƯƠNG1. TỔNGQUANVÀCƠSỞLÝTHUYẾT
1.4.3 Hệ quản trị cơ sở dữ liệu – MySQL
MySQL [7] được lựa chọn làm hệ quản trị cơ sở dữ liệu quan hệ cho các dịch vụ nghiệp
vụ chính. Mỗi Microservice sở hữu cơ sở dữ liệu riêng biệt theo nguyên tắc Database-per-
Service,giúphạnchếphụthuộcchéovàđảmbảotínhtựtrịcủatừngdịchvụ.
ViệctriểnkhaiMySQLtrênKuberneteskếthợpvớiPersistentVolumegiúphệthốngvừa
đảmbảođộbềndữliệu,vừatậndụngđượckhảnăngtựphụchồicủanềntảngcontainer.
1.4.4 Nền tảng phát triển dịch vụ nghiệp vụ – Laravel
Laravel [8] được sử dụng để xây dựng các Microservice nghiệp vụ nhờ kiến trúc MVC
rõ ràng, hệ sinh thái thư viện phong phú và khả năng hỗ trợ tốt cho RESTful API. Các dịch
vụLaravelđượcthiếtkếtheohướngStateless,phùhợpvớimôitrườngcontainervàkiếntrúc
Microservice.
Laravel đồng thời tích hợp tốt với hệ thống xác thực bên ngoài và các cơ chế hàng đợi,
giúpđơngiảnhóaquátrìnhhiệnthựchóacácnghiệpvụphứctạp.
1.4.5 Hạ tầng gửi thư điện tử – Google SMTP
DịchvụgửiemailđượctriểnkhaithôngquaGoogleSMTPnhằmphụcvụcácchứcnăng
thông báo, xác thực và tương tác người dùng trong hệ thống. Việc sử dụng dịch vụ SMTP
bên ngoài giúp hệ thống tránh được gánh nặng vận hành máy chủ mail riêng, đồng thời đảm
bảođộtincậycao,khảnănggửiổnđịnhvàhạnchếnguycơbịđưavàodanhsáchspam.
Cáctácvụgửimailđượcthựchiệnbấtđồngbộthôngquahàngđợi,giúpkhônglàmảnh
hưởngđếnthờigianphảnhồicủacácAPInghiệpvụchính.
APIGateway–Kong
Hệ thống sử dụng Kong Gateway [9] làm cổng vào duy nhất (Ingress) cho toàn bộ kiến
trúc. Kong chịu trách nhiệm định tuyến (Routing), xác thực tập trung (Authentication) và
kiểm soát lưu lượng truy cập (Rate Limiting), giúp giảm tải các xử lý phi nghiệp vụ cho các
Microservicephíasau.
Hệthốngphânphốisựkiện–ApacheKafka
Để hiện thực hóa kiến trúc hướng sự kiện (Event-Driven), Apache Kafka [10] được sử
dụngchoviệcgiaotiếpbấtđồngbộ.Kafkađảmbảođộtincậycao,khảnăngchịulỗivàcho
phépcácdịchvụtraođổithôngtinmàkhôngcầnbiếtvềsựtồntạicủanhau(Decoupling).
5

CHƯƠNG1. TỔNGQUANVÀCƠSỞLÝTHUYẾT
Hệthốnglưutrữđệm–Redis
Redis[11]đượcsửdụngđểlưutrữcácdữliệutruycậpthườngxuyên(Caching)vàquản
lýphiênlàmviệc,giúpgiảmtảichocơsởdữliệuchínhvàtăngtốcđộphảnhồicủahệthống.
Lưutrữđốitượng–MinIO
Thayvìlưutrữfiletrựctiếptrênmáychủứngdụng,hệthốngsửdụngMinIO[12]–một
giải pháp lưu trữ đối tượng hiệu năng cao tương thích với chuẩn Amazon S3. MinIO được
dùng để lưu trữ hồ sơ ứng viên (CV), ảnh đại diện và các tài liệu đính kèm một cách an toàn
vàlinhhoạt.
ỨngdụngWeb–Next.js
Phía người dùng (Frontend) được xây dựng trên Next.js [13] – một framework mạnh mẽ
dựa trên React. Next.js cung cấp các tính năng tối ưu như Server-Side Rendering (SSR) và
Static Site Generation (SSG), giúp ứng dụng đạt tốc độ tải trang nhanh và tối ưu hóa trải
nghiệmchocảứngviênlẫnnhàtuyểndụng.
Côngcụlưutrữnhậtký–Elasticsearch
Elasticsearch [14] đóng vai trò là kho lưu trữ trung tâm cho toàn bộ nhật ký vận hành
(Logs) của hệ thống. Với khả năng tìm kiếm và phân tích phân tán, Elasticsearch cho phép
quảntrịviêntruyvấncáclỗihệthốnghoặcvếtđicủayêucầu(Requesttracing)trênquymô
lớnmộtcáchtứcthời.
Bộthuthậpnhậtký–Filebeat
Hệ thống áp dụng mô hình Sidecar với Filebeat [15] – một tác nhân vận chuyển nhật ký
(Log shipper) trọng lượng nhẹ. Filebeat được cài đặt song song với từng Microservice để
theo dõi các tệp nhật ký, thực hiện gom dữ liệu và đẩy về hệ thống quản lý tập trung mà
khônggâyảnhhưởngđếnhiệunăngcủadịchvụchính.
6

|            |          |          | Chương |              | 2   |       |         |
| ---------- | -------- | -------- | ------ | ------------ | --- | ----- | ------- |
| Phương     | pháp     |          | phân   | tích         | và  | thiết | kế kiến |
|            |          | trúc     |        | Microservice |     |       |         |
| 2.1 Thiết  | kế hướng |          | miền   |              |     |       |         |
| 2.1.1 Giới | thiệu    | về Thiết | kế     | hướng miền   |     |       |         |
Thiếtkếhướngmiền(Domain-DrivenDesign-DDD)làphươngphápluậnthiếtkếphần
mềm được Eric Evans giới thiệu trong tác phẩmkinh điển của mình [16]. DDD đặt miền
nghiệpvụ (businessdomain)làm trungtâmcủa quátrìnhpháttriển, thayvìxuất pháttừcác
yếutốkỹthuậtnhưcơsởdữliệuhayframework.
Triết lý cốt lõi của DDD nhấn mạnh sự cộng tác chặt chẽ giữa các chuyên gia kỹ thuật
vàchuyêngianghiệpvụđểxâydựngNgônngữchung(UbiquitousLanguage)-mộtngôn
ngữ thống nhất được sử dụng xuyên suốt trong mã nguồn, tài liệu thiết kế và giao tiếp giữa
cácbênliênquan.DDDđượccấutrúcthànhhaitầngthiếtkếchính:
• Thiết kế Chiến lược (Strategic Design): Tập trung vào phân tích và phân rã miền
nghiệp vụ lớn thành các phần nhỏ hơn, dễ quản lý. Đây được coi là "bản đồ địa hình
nghiệpvụ"củahệthống.
• Thiết kế Chiến thuật (Tactical Design): Cung cấp các khối xây dựng (building
blocks)vàmẫuthiếtkếcụthểđểtriểnkhaimôhìnhmiềntrongmãnguồn.
| 2.1.2 Tính | cần thiết | của | DDD | trong kiến | trúc | Microservices |     |
| ---------- | --------- | --- | --- | ---------- | ---- | ------------- | --- |
TháchthứclớnnhấtkhixâydựngMicroserviceskhôngnằmởviệcchọnKuberneteshay
Docker, mà nằm ở việc xác định ranh giới dịch vụ (service boundaries) một cách chính
xác. Nếu ranh giới này được thiết kế sai, hệ thống sẽ nhanh chóng rơi vào bẫy "Distributed
7

CHƯƠNG2. PHƯƠNGPHÁPPHÂNTÍCHVÀTHIẾTKẾKIẾNTRÚCMICROSERVICE
Monolith"(Khốinguyênkhốiphântán)-mộttrạngtháitồitệnơimọithayđổinhỏvềnghiệp
vụđềukéotheosựsửađổiđồngbộtrênnhiềudịchvụ.
DDDgiảiquyếtvấnđềnàythôngquacáccơchế:
1. Định nghĩa ranh giới tự nhiên: Ngữ cảnh giới hạn (Bounded Context) cung cấp
phươngphápxácđịnhranhgiớidựatrênnghiệpvụ.
2. Ưu tiên nguồn lực: Phân loại miền con (Subdomain) theo nguyên tắc Pareto - Core
Domainthườngchỉchiếm20%giátrịhệthốngnhưngđòihỏi80%nỗlựcsángtạo.
3. Quảnlýnhấtquándữliệu:Hỗtrợthiếtkếhệthốngphântánvớitínhnhấtquáncuối
cùng(eventualconsistency)thôngquaDomainEvents.
4. Tuân thủ Định luật Conway: Đảm bảo cấu trúc hệ thống phản ánh cấu trúc tổ chức,
giảmmasáttrongpháttriển.
2.1.3 Thiết kế Chiến lược (Strategic Design)
PhânloạiMiềncon(Subdomain)-Labànđầutưnguồnlực
DDD đề xuất phân rã miền nghiệp vụ thành các Subdomain để định hướng chiến lược
đầutư:
Bảng2.1:PhânloạiMiềncontrongDDD
Loạimiềncon Đặcđiểm Lợithế ChiếnlượcMicroservice
CoreDomain Độcnhất,logicphứctạp,thay Rấtcao Xây dựng in-house với đội
đổithườngxuyên. ngũgiỏinhất.
Supporting Cần thiết để vận hành nhưng Thấp Xây dựng nội bộ hoặc
khôngtạokhácbiệt. outsource.
Generic Phổ biến, đã được chuẩn hóa Không Chiến lược "Mua thay vì
(Email,Auth). Xây"(SaaS/OpenSource).
NgữcảnhGiớihạn(BoundedContext)
Định nghĩa: Ngữ cảnh Giới hạn (Bounded Context - BC) là ranh giới rõ ràng nơi một
môhìnhmiềncụthểcóýnghĩathốngnhất.Mộttừngữcóthểmangnhiềuýnghĩakhácnhau
tùythuộcngữcảnh.
8

CHƯƠNG2. PHƯƠNGPHÁPPHÂNTÍCHVÀTHIẾTKẾKIẾNTRÚCMICROSERVICE
Hình2.1:Từngữ"Sảnphẩm"trongcácBoundedContextkhácnhau
Ví dụ: thực thể "Sản phẩm"(Product) trong Sales Context tập trung vào giá và khuyến
mãi, trong khi ở Marketing Context, "Sản phẩm"lại được biểu diễn thông qua các khía cạnh
nhưđịnhvịthịtrường,nhómkháchhàngmụctiêu,thôngđiệpthươnghiệuvàmứcđộtương
tác của các chiến dịch marketing, phản ánh mục tiêu thu hút và xây dựng nhận thức thương
hiệu.
Mối quan hệ với Microservice: Lý tưởng nhất là tỷ lệ 1:1 (Một Microservice bao trùm
trọn vẹn một Bounded Context). Tuy nhiên, một Microservice không nên nhỏ hơn một
AggregatevàkhôngnênlớnhơnmộtBoundedContext.
ContextMapping-Địnhhìnhquanhệxãhộivàkỹthuật
ContextMapphảnánhmốiquanhệgiữacácđộinhómvàsựphụthuộckỹthuật:
Bảng2.2:CácmẫuquanhệchínhtrongContextMapping
Mẫuquanhệ Môtả Sựphụthuộc
Partnership Haiđộiphốihợpchặtchẽ,thấtbạimộtbênlàthất Rấtcao
bạicảhai.
SharedKernel Chia sẻ một phần nhỏ mô hình (thư viện Value Cao
Objectschung).
Customer-Supplier Upstream cung cấp dịch vụ, Downstream có Trungbình
quyềnyêucầu.
Conformist Downstream buộc phải chấp nhận mô hình của Cao
Upstream.
ACL Lớpchốngthamnhũngbảovệmôhìnhmiềntinh Thấp
sạch.
OpenHost(OHS) Cung cấp giao thức chuẩn công khai cho nhiều Thấp
Downstream.
9

CHƯƠNG2. PHƯƠNGPHÁPPHÂNTÍCHVÀTHIẾTKẾKIẾNTRÚCMICROSERVICE
2.1.4 Thiết kế Chiến thuật (Tactical Design)
EntityvàValueObject
• Entity (Thực thể): Đối tượng được xác định bởi định danh (Identity) duy nhất, có
vòngđờivàtrạngtháithayđổi(Vídụ:Order,Candidate).
• Value Object (Đối tượng giá trị): Đối tượng xác định bởi giá trị thuộc tính, bất biến
(Immutable)vàantoànđaluồng(Vídụ:Address,Money).
Cụmthựcthể
Cụm thực thể (Aggregate) là cụm các Entity và Value Object liên quan chặt chẽ, được
coi là một đơn vị nhất quán duy nhất cho các thay đổi dữ liệu. Mọi thay đổi phải thông qua
AggregateRoot.CácquytắcthiếtkếcụmthựcthểtrongMicroservice:
1. BảovệInvariants:Đảmbảomọiquytắcnghiệpvụluônđúngsaugiaodịch.
2. Thiết kế nhỏ (Small Aggregates): Tránh "God Aggregate"(Cụm thực thể lớn quá
mức)gâyvấnđềhiệunăngvàtranhchấpkhóa(locking).
3. Tham chiếu bằng ID: Các cụm thực thể không chứa tham chiếu trực tiếp đến nhau,
chỉgiữIDđểtạoranhgiớivậtlýcứng.
4. Tính nhất quán cuối cùng: Cập nhật các cụm thực thể liên quan bất đồng bộ qua
DomainEvents.
Dịchvụmiềnvàdịchvụứngdụng-DomainServicevsApplicationService
Domain Service vs Application Service DDD giúp tránh Anemic Domain Model (Mô
hìnhmiềnthiếumáu-thựcthểchỉcódữliệu,khôngcóhànhvi)bằngcáchphânđịnh:
• Domain Service: Chứa logic nghiệp vụ không thuộc về một Entity cụ thể, nằm trong
lớpCore.
• Application Service: Điều phối luồng công việc (Facade), không chứa logic nghiệp
vụ,nằmởlớpvỏứngdụng.
2.1.5 Kiến trúc hệ thống - Vỏ bọc bảo vệ Domain
HexagonalArchitecture(PortsandAdapters)
ĐâylàkiếntrúctrungtâmchoDDDMicroservices,đảmbảologicnghiệpvụkhôngphụ
thuộckỹthuật:
10

CHƯƠNG2. PHƯƠNGPHÁPPHÂNTÍCHVÀTHIẾTKẾKIẾNTRÚCMICROSERVICE
• Core(Hexagon):ChứaDomainEntities,ValueObjectsvàDomainServices.
• Ports:CácInterfaceđịnhnghĩacáchgiaotiếp(Inbound/Outbound).
• Adapters:Triểnkhaicụthể(RESTController,KafkaConsumer,SQLRepository).
2.1.6 Giao tiếp và Tính nhất quán dữ liệu phân tán
TransactionalOutboxPattern-Giảiquyết"Dual-Write"
KhimộtdịchvụvừaphảighiDatabasevừaphảigửisựkiệnlênKafka,nguycơmấtđồng
bộlàrấtcao.GiảiphápOutboxthựchiện:
1. GhiEventvàobảngOutbox trongcùngmộtTransactionvớidữliệunghiệpvụ.
2. Sử dụng Log-based CDC (Change Data Capture) như Debezium để đọc Transaction
LogvàđẩylênMessageBroker.
2.1.7 Case Study: Phân tích Online Boutique với DDD
HệthốngdemocủaGoogleCloudgồm11microservicesminhhọaviệcápdụngDDD:
• CoreDomain(40%):ProductCatalog,Cart,Checkout.Đâylàcácdịchvụtạolợithế
cạnhtranh.
• SupportingDomain(40%):Frontend,Payment,Shipping.
• GenericDomain(20%):EmailService,CurrencyConversion.
MốiquanhệgiữacácdịchvụđượcđiềuphốiquaSagaOrchestration(tạiCheckoutService)
vàđồngbộquaKafka,đảmbảotínhnhấtquáncuốicùngchohệthống.
2.1.8 Kết luận
ThiếtkếhướngmiềncungcấpkhungtưduyhệthốngđểxâydựngkiếntrúcMicroservices
bềnvững.Việctôntrọngranhgiớivậtlý,bảovệtínhnhấtquánthôngquaAggregatevàgiao
tiếpbấtđồngbộquaDomainEventslàchìakhóađểvậnhànhhệthốngphântánhiệuquả.
2.2 Các mẫu thiết kế giao tiếp và tích hợp
Trong kiến trúc Microservice, việc giao tiếp giữa các dịch vụ không còn là lời gọi hàm
trongcùngbộnhớ(in-processcalls)màtrởthànhcáclờigọiquamạng(networkcalls).Điều
nàyđòihỏicácmẫuthiếtkếphảiđảmbảotínhtincậy,hiệunăngvàkhảnăngmởrộng.
11

CHƯƠNG2. PHƯƠNGPHÁPPHÂNTÍCHVÀTHIẾTKẾKIẾNTRÚCMICROSERVICE
2.2.1 Giao tiếp đồng bộ (Synchronous Communication)
Giao tiếp đồng bộ yêu cầu dịch vụ gửi (Client) phải chờ đợi phản hồi từ dịch vụ nhận
(Server)trướckhitiếptụcthựchiệncáctiếntrìnhtiếptheo.
REST API (Representational State Transfer): Đây là giao thức phổ biến nhất dựa trên
HTTP. REST sử dụng các phương thức chuẩn (GET, POST, PUT, DELETE) và định dạng
JSONđểtraođổidữliệu.
• Ưu điểm: Đơn giản, dễ kiểm thử, được hỗ trợ bởi mọi ngôn ngữ lập trình và tương
thíchtốtvớicáchệthốngbênngoài.
• Nhược điểm: Tạo ra sự phụ thuộc về thời gian (Temporal Coupling). Nếu chuỗi gọi
dịchvụ(ServiceChain)quádài,độtrễsẽtíchtụvànếumộtdịchvụởgiữabịlỗi,toàn
bộyêucầusẽthấtbại.
2.2.2 Giao tiếp bất đồng bộ và Kiến trúc hướng sự kiện
Để giải quyết vấn đề phụ thuộc chặt của giao tiếp đồng bộ, giao tiếp bất đồng bộ cho
phépdịchvụgửithôngđiệpvàtiếptụccôngviệccủamìnhmàkhôngcầnchờphảnhồingay
lậptức.
CơchếMessageQueuing
Sử dụng một Message Broker (như Kafka hoặc RabbitMQ) làm trung gian. Dịch vụ gửi
(Producer)đẩythôngđiệpvàohàngđợi(Queue),dịchvụnhận(Consumer)sẽlấythôngđiệp
ra xử lý khi có tài nguyên rảnh. Cơ chế này giúp "là phẳng"các đỉnh tải (load leveling) và
đảmbảothôngđiệpkhôngbịmấtnếudịchvụnhậntạmthờingoạituyến.
Kiếntrúchướngsựkiện(Event-DrivenArchitecture-EDA)
Trongmôhìnhnày,cácdịchvụgiaotiếpthôngquaviệcphátvànhậncácsựkiện(Events).
• Domain Event: Đại diện cho một sự kiện nghiệp vụ đã xảy ra (ví dụ: JobPublished,
CandidateApplied).
• LooseCoupling:Dịchvụphátsựkiệnkhôngcầnbiếtaisẽnhậnsựkiệnđó.Điềunày
chophépdễdàngthêmcácdịchvụmới(nhưdịchvụgửithôngbáo,dịchvụthốngkê)
vàohệthốngmàkhôngcầnsửađổimãnguồncủadịchvụgốc.
12

CHƯƠNG2. PHƯƠNGPHÁPPHÂNTÍCHVÀTHIẾTKẾKIẾNTRÚCMICROSERVICE
2.2.3 Thiết kế API Gateway và Backend for Frontend (BFF)
Khi hệ thống có hàng chục Microservice, việc để Client (Web/Mobile) gọi trực tiếp đến
từngdịchvụlàmộtsailầmvềbảomậtvàhiệunăng.
APIGateway
APIGatewayđóngvaitròlàcửangõduynhất(SingleEntryPoint)chotấtcảcácyêucầu
từbênngoài.Cáctráchnhiệmchínhbaogồm:
• Routing:Điềuhướngyêucầuđếnđúngdịchvụđích.
• Authentication&Authorization:Kiểmtraquyềntruycậptậptrung(thườngtíchhợp
vớiKeycloak).
• RateLimiting:GiớihạnsốlượngyêucầuđểchốngtấncôngDoS.
• Offloading:Xửlýcáctácvụchungnhưnéndữliệu,SSLTermination.
BackendforFrontend(BFF)
Thay vì sử dụng một API Gateway chung cho mọi thiết bị, mẫu BFF đề xuất xây dựng
cácAPItrunggianriêngbiệtchotừngloạiClient(WebApp,MobileiOS,MobileAndroid).
• Lý do: Mobile Client thường có băng thông thấp và màn hình nhỏ, cần ít dữ liệu hơn
WebClient.BFFgiúptổnghợpdữliệu(DataAggregation)từnhiềudịchvụthànhmột
phảnhồiduynhất,giảmsốlượngrequesttừthiếtbịcầmtay.
NguyêntắcthiếtkếvàPhiênbảnhóaAPI
Đểđảmbảotínhổnđịnhkhihệthốngtiếnhóa,thiếtkếAPIcầntuânthủ:
• Tính tương thích ngược: Tránh thực hiện các thay đổi làm hỏng ứng dụng đang chạy
củaClient(Breakingchanges).
• Phiên bản hóa (Versioning): Sử dụng phiên bản trong URL (ví dụ: /api/v1/...)
hoặc trong Header. Điều này cho phép chạy song song nhiều phiên bản API, giúp
Clientcóthờigianchuyểnđổidầnsangphiênbảnmới[1,tr.147].
2.3 Quản lý dữ liệu và tính nhất quán
TrongMicroservice,mỗidịchvụsởhữumộtcơsởdữliệuriêng(DatabaseperService).
Điều này ngăn cản việc sử dụng các truy vấn JOIN giữa các bảng của các dịch vụ khác nhau
vàcácgiaodịchACIDđadịchvụ.
13

| CHƯƠNG2. | PHƯƠNGPHÁPPHÂNTÍCHVÀTHIẾTKẾKIẾNTRÚCMICROSERVICE |     |     |     |     |
| -------- | ----------------------------------------------- | --- | --- | --- | --- |
Bảng2.3:SosánhgiaotiếpĐồngbộvàBấtđồngbộ
| Tiêuchí | Đồngbộ(REST) |             |      | Bấtđồngbộ(Events)              |     |
| ------- | ------------ | ----------- | ---- | ------------------------------ | --- |
| Độtrễ   | Thấp         | (trong điều | kiện | bình Caohơn(dođộtrễcủaBroker). |     |
thường).
Tínhsẵnsàng Phụthuộcvàodịchvụnhận. Cao,dịchvụgửivẫnchạynếudịch
vụnhậnlỗi.
Độphứctạp Thấp,dễpháttriểnvàdebug. Cao, khó theo dõi luồng dữ liệu
(tracing).
Sựphụthuộc Phụthuộcchặtvềthờigian. Liênkếtlỏng(Looselycoupled).
| 2.3.1 Tính | nhất quán | cuối cùng |     |     |     |
| ---------- | --------- | --------- | --- | --- | --- |
HệthốngMicroserviceưutiêntínhsẵnsàng(Availability)vàkhảnăngchịulỗi(Partition
Tolerance) theo định lý CAP. Thay vì đảm bảo dữ liệu cập nhật ngay lập tức ở mọi nơi, hệ
thốngđảmbảorằngsaumộtkhoảngthờigian,tấtcảcácdịchvụsẽđạtđượctrạngtháithống
nhấtthôngquaviệctruyềnthôngđiệp.
CácmẫuthiếtkếdướiđâyđượctổnghợpchitiếttrênMicroservices.io[17].
| 2.3.2 Mẫu | CQRS (Command |     | Query | Responsibility | Segregation) |
| --------- | ------------- | --- | ----- | -------------- | ------------ |
CQRStáchbiệthoàntoànđườngdẫnxửlýlệnhGhi(Command)vàlệnhĐọc(Query):
• CommandSide:Tốiưuhóachoviệckiểmtraquytắcnghiệpvụvàghidữliệu(thường
làRDBMS).
• Query Side: Tối ưu hóa cho việc tìm kiếm và hiển thị. Dữ liệu ở đây thường được
"phẳng hóa"(Denormalized) và lưu trong các công cụ như Elasticsearch để đạt tốc độ
truyvấncựcnhanh.
| 2.3.3 Mẫu | Saga (Quản | lý giao | dịch | phân tán) |     |
| --------- | ---------- | ------- | ---- | --------- | --- |
Saga là một chuỗi các giao dịch cục bộ. Mỗi giao dịch cập nhật cơ sở dữ liệu bên trong
một dịch vụ và phát ra một sự kiện để kích hoạt bước tiếp theo. Nếu một bước thất bại, Saga
sẽ kích hoạt các Compensating Transactions (Giao dịch bù) để hoàn tác các bước trước đó,
đảmbảotínhtoànvẹncủadữliệunghiệpvụ[1].
| 2.3.4 Mẫu | Event Sourcing |     |     |     |     |
| --------- | -------------- | --- | --- | --- | --- |
Thay vì chỉ lưu trạng thái hiện tại (ví dụ: Số dư = 100$), Event Sourcing lưu trữ toàn bộ
lịchsửcácsựkiệnđãdẫnđếntrạngtháiđó(Nạp50$,Nạp70$,Rút20$).Điềunàycungcấp
khả năng kiểm toán (Audit Trail) tuyệt vời và cho phép tái tạo trạng thái hệ thống tại bất kỳ
thờiđiểmnàotrongquákhứ.
14

CHƯƠNG2. PHƯƠNGPHÁPPHÂNTÍCHVÀTHIẾTKẾKIẾNTRÚCMICROSERVICE
2.4 Hạ tầng và Vận hành
Mặc dù Microservices mang lại nhiều lợi ích về mặt phát triển và mở rộng, nhưng trên
thựctếkiếntrúcnàycũnglàmtăngđángkểđộphứctạptrongvậnhànhhệthống.Đểmộthệ
thống gồmnhiều dịchvụ nhỏ hoạtđộng trơn tru,cần cómột hạ tầngtự động hóacao vàkhả
nănggiámsáttoàndiện[2,tr.79].
2.4.1 Cơ chế Service Discovery (Khám phá dịch vụ)
Trong môi trường container hóa (như Docker hay Kubernetes), các instance của dịch vụ
thường có tính chất tạm thời (ephemeral) – chúng có thể được khởi tạo, dừng lại hoặc thay
đổiđịachỉIPbấtcứlúcnào.Dođó,việccấuhìnhcứngđịachỉIPlàkhôngkhảthi.
Cơ chế hoạt động: Service Discovery sử dụng một kho lưu trữ trung tâm gọi là Service
Registry(vídụ:Consul,EurekahoặcK8sDNS).
• Registration:Khimộtdịchvụkhởiđộng,nótựđăngkýthôngtin(têndịchvụ,địachỉ
IP,cổng)vớiRegistry.
• Discovery: Khi dịch vụ A muốn gọi dịch vụ B, nó sẽ gửi truy vấn đến Registry để lấy
danhsáchcácIPđanghoạtđộngcủadịchvụB.
• HealthCheck:Registryđịnhkỳkiểmtratìnhtrạngcủacácdịchvụ.Nếumộtinstance
bị lỗi, Registry sẽ gỡ tên nó khỏi danh sách để tránh gửi yêu cầu đến một "dịch vụ
chết".
2.4.2 Cơ chế Load Balancing (Cân bằng tải)
Load Balancing đảm bảo lưu lượng truy cập được phân phối đều cho các instance của
dịchvụ,ngănchặntìnhtrạngmộtinstancebịquátảitrongkhicácinstancekhácrảnhrỗi.
• Server-side Load Balancing: Một bộ cân bằng tải tập trung (như Nginx, HAProxy)
nhậnyêucầuvàđiềuphốiđếncácdịchvụbêndưới.
• Client-side Load Balancing: Dịch vụ gửi yêu cầu sẽ tự quyết định instance nào sẽ
nhận yêu cầu dựa trên danh sách lấy từ Service Registry. Điều này giúp giảm tải cho
bộcânbằngtảitậptrungvàloạibỏđiểmchếtduynhất(SinglePointofFailure).
2.4.3 Giám sát tập trung và Observability (Khả năng quan sát)
Với hàng chục dịch vụ chạy riêng lẻ, việc đăng nhập vào từng server để kiểm tra log là
khôngthể.HệthốngMicroservicehiệnđạiyêucầubatrụcộtcủaObservability[1]:
15

CHƯƠNG2. PHƯƠNGPHÁPPHÂNTÍCHVÀTHIẾTKẾKIẾNTRÚCMICROSERVICE
CentralizedLogging(Logtậptrung)
Toàn bộ nhật ký hoạt động (Logs) từ tất cả các Microservice, API Gateway và Database
được thu thập về một kho lưu trữ tập trung (thường sử dụng ELK Stack: Elasticsearch -
Logstash - Kibana). Điều này cho phép quản trị viên tìm kiếm và phân tích lỗi trên toàn hệ
thốngtừmộtgiaodiệnduynhất.
DistributedTracing(Theovếtphântán)
Khimộtyêucầutừngườidùngđiquachuỗinhiềudịchvụ,việcxácđịnhdịchvụnàogây
ralỗihoặcchậmtrễlàrấtkhókhăn.
• Correlation ID: Mỗi yêu cầu được gán một mã định danh duy nhất ngay tại API
Gateway.Mãnàyđượctruyềnđixuyênsuốtquacáclờigọiliêndịchvụ.
• Công cụ: Các hệ thống như Jaeger hoặc Zipkin giúp trực quan hóa vết đi của yêu cầu
dưới dạng biểu đồ thời gian (Timeline), giúp nhanh chóng phát hiện các nút thắt cổ
chai(bottlenecks).
MetricsvàHealthMonitoring
Theodõicácthôngsốđịnhlượngnhư:tỷlệlỗi(ErrorRate),thờigianphảnhồi(Latency),
và mức độ sử dụng tài nguyên (CPU, RAM). Các công cụ như Prometheus kết hợp với
Grafanagiúpcảnhbáochủđộng(ProactiveAlerting)trướckhisựcốnghiêmtrọngxảyra.
2.4.4 Quy trình triển khai và văn hóa DevOps
Microservice yêu cầu một quy trình triển khai liên tục (CI/CD) tự động hóa hoàn toàn.
Mỗi thay đổi mã nguồn phải đi qua các bước kiểm thử tự động (Unit Test, Integration Test)
trước khi được đóng gói thành Image và triển khai lên môi trường sản xuất mà không cần sự
canthiệpthủcông[1,tr.257].
Thiếtkếchosựthấtbại(DesignforFailure): Tronghệthốngphântán,lỗilàđiềukhông
thểtránhkhỏi.Cáckỹsưphảithiếtkếhệthốngsaochokhimộtthànhphầnthấtbại,toànbộ
ứng dụng không bị sụp đổ (Graceful Degradation). Ví dụ: Nếu dịch vụ gợi ý việc làm bị lỗi,
hệthốngvẫnphảichophépngườidùngxemtintuyểndụngvàứngtuyểnbìnhthường.
2.5 Kết luận chương 2
Chương 2 đã trình bày chi tiết về phương pháp luận và các mẫu thiết kế cốt lõi của kiến
trúc Microservice. Từ việc phân rã dịch vụ dựa trên Domain-Driven Design, thiết lập cơ chế
16

CHƯƠNG2. PHƯƠNGPHÁPPHÂNTÍCHVÀTHIẾTKẾKIẾNTRÚCMICROSERVICE
giao tiếp hướng sự kiện đến việc xây dựng hạ tầng vận hành tự động. Đây là nền tảng lý
thuyếtquantrọngđểtiếnhànhxâydựngvàtriểnkhaithựcnghiệmhệthốngTuyểndụngtrực
tuyếntrongchươngtiếptheo.
17

Chương 3
Xây dựng hệ thống Tuyển dụng trực
tuyến
3.1 Phân tích yêu cầu nghiệp vụ
3.1.1 Khảo sát và thu thập yêu cầu nghiệp vụ
Để xây dựng một quy trình nghiệp vụ chuẩn hóa và phù hợp với thực tiễn, đồ án đã tiến
hànhthamkhảomôhìnhhoạtđộngcủacácnềntảngtuyểndụnguytín.Đốivớiphânhệquản
lý tin đăng và tìm kiếm việc làm (Job Portal), đồ án tham khảo quy trình tiếp cận ứng viên
của các mạng lưới phổ biến như LinkedIn [18] và Indeed [19]. Tại thị trường Việt Nam, các
quytrìnhvềđăngtuyểnvàquảnlýhồsơứngviênđượcthamchiếutheomôhìnhcủaTopCV
[20] và VietnamWorks [21] để đảm bảo tính phù hợp với người dùng trong nước. Đặc biệt,
đối với phân hệ quản trị tuyển dụng (Hiring Service/ATS), chức năng quản lý ứng viên theo
quytrình(Pipeline)vàbảngđiềukhiển(KanbanBoard)đượcthiếtkếdựatrênnguyênlýcủa
các hệ thống ATS chuyên nghiệp như Greenhouse [22] và SmartRecruiters [23]. Việc tham
khảo này giúp hệ thống Job7189 không chỉ dừng lại ở việc đăng tin mà còn hỗ trợ doanh
nghiệpquảnlýtrọnvẹnvòngđờituyểndụng.
Việckhảosáttậptrungvàocácnộidungchính:
• Luồngđăngtuyểnvàquảnlýtintuyểndụng.
• Luồngứngtuyểnvàxửlýhồsơứngviên.
• Cáchcáchệthốnghiệntạiquảnlýtrạngtháitintuyểndụngvàhồsơ.
• Quy trình phối hợp giữa các vai trò: Recruiter, Hiring Manager, HR, Admin và Ứng
viên.
18

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
Kếtquảkhảosátchothấy,mặcdùmỗinềntảngcócáchtriểnkhairiêng,nhưngđasốcác
hệthốngđềutuântheocácluồngnghiệpvụchung:
• Tintuyểndụng đượckhởi tạo,chỉnhsửa, gửiduyệt,công bốvà kếtthúctheo vòngđời
trạngthái;
• Hồsơứngviênđượctiếpnhận,sànglọc,phỏngvấn,đánhgiávàcậpnhậtkếtquảtheo
quytrìnhnhiềubước;
• Mọithayđổiquantrọngđềuđượcghinhậnlịchsửđểphụcvụtheodõi,báocáovàđối
soátdữliệu;
• Cácvaitròthamgiađượcphânquyềnrõràngtrongtừnggiaiđoạncủaquytrình.
Trên cơ sở các luồng và quy trình nghiệp vụ thu được từ khảo sát, đồ án tiến hành xây
dựng hệ thống tuyểndụng với mục tiêu chuẩn hóa quytrình, kiểm soát chặt chẽ vòng đờidữ
liệuvàđảmbảotínhnhấtquántrongtoànbộhoạtđộngtuyểndụng.Dựatrêncácnghiêncứu
vềquytrìnhtuyểndụnghiệuquả[24]vàkhảosátcácnềntảngthựctế.
3.1.2 Mô hình hóa quy trình nghiệp vụ (BPMN)
Dựatrênquátrìnhkhảosátcáchệthốngthựctế,đồánmôhìnhhóacácquytrìnhnghiệp
vụ cốt lõi của hệ thống tuyển dụng. Mục tiêu là làm rõ cách thức vận hành thực tế, các vai
trò tham gia, cũng như các quy tắc nghiệp vụ chi phối vòng đời của dữ liệu trong hệ thống.
Trong đó, Quy trình Đăng tuyển (Job Posting Lifecycle) được xác định là quy trình trung
tâm,ảnhhưởngtrựctiếpđếntoànbộhoạtđộngcủanềntảngtuyểndụng.
QuytrìnhĐăngtuyển
Hình3.1:SơđồQuytrìnhĐăngtuyển
1.Giaiđoạnsoạnthảo
Môtảnghiệpvụ:Ngườiphụtráchviệcđăngbàikhởitạomộttintuyểndụngmớivànhậpcác
thôngtinmôtảcôngviệc(JobDescription):tiêuđềcôngviệc,môtảnhiệmvụ,yêucầuứng
viên, mức lương, địa điểm làm việc, hình thức làm việc, thời hạn ứng tuyển và các thông tin
liên quan khác. Sau khi được tạo, tin tuyển dụng được lưu ở trạng thái DRAFT và chỉ hiển
thịvớinhữngngườicóquyềntruycập.
19

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
Tại giai đoạn này, hệ thống không cho phép xóa tin tuyển dụng trong bất kỳ trường hợp
nào, kể cả khi tin mới được tạo và chưa gửi duyệt. Thay vì cơ chế xóa, hệ thống áp dụng mô
hìnhquảnlývòngđờibằngchuyểntrạngtháivàlưutrữ(Archive)nhằm:
• Bảotoàndữliệunghiệpvụ.
• Đảmbảokhảnăngtruyvếtlịchsửxửlýtin.
• Duytrìsựliênkếtgiữatintuyểndụngvàcácdữliệuphátsinhnhưhồsơứngviên,báo
cáovàthốngkê.
Trong giai đoạn soạn thảo, người phụ trách tuyển dụng được phép: Chỉnh sửa nội dung tin,
Lưutrữtạmthờitinnếuchưatiếptụcxửlý,Gửitinđểchuyểnsanggiaiđoạnkiểmduyệt.
2.Giaiđoạngửiduyệt
Môtảnghiệpvụ:Khinộidungtinđãđượchoànthiện,ngườiphụtráchtuyểndụngthựchiện
thao tác Submit. Hệ thống tiếp nhận yêu cầu và chuyển tin sang trạng thái PENDING. Tại
thời điểm này, nội dung tin không được phép chỉnh sửa nhằm đảm bảo tính nhất quán trong
suốt quá trình kiểm tra. Trong trường hợp phát hiện sai sót, người phụ trách tuyển dụng có
thểhủygửiduyệtđểđưatinquaylạigiaiđoạnsoạnthảovàtiếptụcchỉnhsửa.
3.Giaiđoạnkiểmduyệt
Mô tả nghiệp vụ: Bộ phận quản trị nền tảng tiến hành rà soát các tin đang chờ duyệt từ các
đơn vị khác nhau theo các quy chuẩn đã được thiết lập trước. Sau khi đánh giá, nội dung tin
sẽđượcxửlýtheomộttronghaihướng:
• Chấpthuận:Tinđượcchophépcôngbốtrênhệthống.
• Từchối:Tinbịyêucầuchỉnhsửalạinộidungvàgửiduyệtlại.
4.Giaiđoạnvậnhànhvàkếtthúc
Mô tả nghiệp vụ: Các tin đã được chấp thuận sẽ được hiển thị công khai cho ứng viên trong
thời gian hiệu lực. Tin tuyển dụng kết thúc khi: Hết thời hạn đăng tuyển; Doanh nghiệp chủ
độngngừnghiểnthịtin;Admincủahệthốnggỡtin.Cáctinkếtthúcđượclưutrữđểphụcvụ
côngtácbáocáo,thốngkêvàđốisoátdữliệutrongtươnglai.
QuytrìnhỨngtuyển
Quy trình Ứng tuyển mô tả toàn bộ hành trình của một ứng viên kể từ khi tiếp cận tin
tuyểndụngchođếnkhinhậnđượckếtquảcuốicùngtừphíadoanhnghiệp.Quytrìnhnàykết
nối trực tiếp giữa người tìm việc và tổ chức tuyển dụng, đồng thời tạo ra chuỗi dữ liệu đầu
vàoquantrọngchocáchoạtđộngsànglọc,phỏngvấnvàraquyếtđịnhtuyểndụng.
1.GiaiđoạnTìmkiếm&Tiếpcậnviệclàm
Môtảnghiệpvụ:Ngườitìmviệctruycậpcổngthôngtintuyểndụng(JobPortal)vàsửdụng
20

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
Hình3.2:SơđồQuytrìnhỨngtuyển
các chức năng tìm kiếm, lọc, sắp xếp để tra cứu các vị trí tuyển dụng phù hợp theo nhiều
tiêu chí như: ngành nghề, địa điểm, mức lương, hình thức làm việc và kinh nghiệm yêu cầu.
Tại giai đoạn này, người dùng có thể xem chi tiết nội dung tin tuyển dụng, thông tin doanh
nghiệpvàcácyêucầuliênquantrướckhiquyếtđịnhứngtuyển.
2.GiaiđoạnỨngtuyển
Môtảnghiệpvụ:Khiquyếtđịnhứngtuyển,ứngviênthựchiệnthaotácnộphồsơ.Hệthống
chophépứngviên:TảilênCVtừthiếtbịcánhânhoặcchọntừhồsơđãlưutrướcđó,bổsung
các thông tin cần thiết theo mẫu ứng tuyển. Hồ sơ của ứng viên được lưu trữ trên hệ thống
lưu trữ tập trung (Storage Service) và hệ thống đồng thời tạo một bản ghi Application gắn
vớitintuyểndụngtươngứng,chínhthứcghinhậnviệcứngtuyểncủaứngviên.
3.GiaiđoạnSànglọc&Phỏngvấn
Mô tả nghiệp vụ: Sau khi tiếp nhận hồ sơ, đội ngũ tuyển dụng tiến hành xem xét danh sách
ứng viên cho từng vị trí. Recruiter và Hiring Manager đánh giá hồ sơ dựa trên các tiêu chí
chuyênmônvàyêucầucôngviệc.Đốivớicáchồsơphùhợp,bộphậnđiềuphốituyểndụng
(Coordinator) thực hiện liên hệ và lên lịch phỏng vấn. Quá trình phỏng vấn được thực hiện
bởi các Interviewer, trong đó kết quả đánh giá và nhận xét được ghi nhận trực tiếp vào hệ
thống. Quy trình này có thể bao gồm nhiều vòng phỏng vấn và các hoạt động đánh giá bổ
sungtùytheochínhsáchtuyểndụngcủatừngtổchức.
4.GiaiđoạnKếtquả&Thôngbáo
Môtảnghiệpvụ:Saukhihoàntấtcácvòngđánhgiá,hệthốngcậpnhậttrạngtháicuốicùng
của hồ sơ ứng viên: Offer đối với ứng viên đạt yêu cầu, Reject đối với các hồ sơ không phù
hợp.Kếtquảnàyđượcthôngbáođếnứngviênthôngquacáckênhliênlạccủahệthốngnhư
email hoặc thông báo trên nền tảng, đồng thời được lưu trữ để phục vụ mục đích báo cáo và
thốngkêtrongtươnglai.
3.1.3 Biểu đồ Use Case và Đặc tả chức năng
BiểuđồUseCasetổngquátcủahệthốngJob7189đượcthiếtkếdựatrêncáckýpháptiêu
chuẩn của Ngôn ngữ Mô hình hóa Thống nhất (UML) theo hướng dẫn của Fowler [25]. Quá
trình xác định các tác nhân (Actors) và ca sử dụng (Use Cases) tuân thủ phương pháp phân
tích thiết kế hướng đối tượng được đề xuất bởi Larman [26], nhằm đảm bảo bao quát đầy đủ
cáctươngtácgiữangườidùngvàhệthống.
21

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
(a)Phần1 (b)Phần2
Hình3.3:BiểuđồUseCasehệthốngtuyểndụng
Danhsáchtácnhânhệthống(Actors)
Hệ thống phân định rõ ràng trách nhiệm của từng vai trò tham gia vào quy trình tuyển
dụng. Việc phân chia chi tiết giữa các vai trò như Recruiter, Hiring Manager và Interviewer
được thiết kế dựa trên nguyên lý tuyển dụng "Who: The A Method"[24] nhằm đảm bảo tính
kháchquanvàhiệuquả.
Dướiđâylàdanhsáchchitiếtcáctácnhântronghệthống:
22

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
Bảng3.1:Đặctảcáctácnhânvàquyềnhạntronghệthống
STT Tácnhân(Actor) Môtảchitiết
1 SystemAdmin Quản trị viên cấp cao nhất. Quản lý toàn bộ nền tảng (multi-
tenancy),baogồmquảnlýcácworkspace,kiểmduyệttinđăng
côngkhaivàcấuhìnhthamsốtoàncục.
2 WorkspaceAdmin Quản trị viên của một công ty (tenant). Chịu trách nhiệm cấu
hìnhworkspace,mờithànhviên,phânquyềnvàgiámsáthoạt
độngtuyểndụngcủacôngty.
3 RecOps Chuyên viên vận hành tuyển dụng. Người thiết kế luồng
quy trình (Pipeline), tạo mẫu đánh giá (Scorecard), cấu hình
automationvàemailtemplate.
4 Recruiter Chuyên viên tuyển dụng toàn trình. Người "sở hữu"ứng viên,
chịu trách nhiệm đăng tin, sàng lọc (sourcing), quản lý ứng
viênquacácvòngvàgửiOffer.
5 Coordinator Điều phối viên. Chịu trách nhiệm về logistics: lên lịch phỏng
vấn,đặtphònghọpvàgửithưmời.Khôngthamgiavàoquyết
địnhtuyểndụng.
6 HiringManager Trưởng bộ phận cần tuyển (người ra quyết định). Tạo yêu cầu
tuyển dụng (Requisition), tham gia phỏng vấn và phê duyệt
Offercuốicùng.
7 Interviewer Người phỏng vấn. Bất kỳ nhân viên nào được mời tham gia
đánh giá ứng viên. Hệ thống áp dụng cơ chế "Independent
Feedback"(khôngđượcxemđánhgiácủangườikháctrướckhi
nộpđánhgiácủamình).
8 Member Nhân viên thông thường. Có thể xem tin tuyển dụng nội bộ,
giớithiệuứngviên(Referral)vàquảnlýhồsơcánhân.
9 Guest Kháchvãnglaichưađăngnhập.Chỉcóquyềnxemdanhsách
việclàmcôngkhai(JobBoard)vàtìmkiếmthôngtin.
10 Candidate Ứngviênđãđăngkýtàikhoản.Cóquyềnquảnlýhồsơ(CV),
ứng tuyển (Apply), theo dõi trạng thái đơn và thực hiện các
quyềnriêngtưdữliệu.
11 User Thựcthểcơsở(BaseUser)tronghệthốngđịnhdanh.Mọitác
nhân (trừ Guest) đều kế thừa từ User để thực hiện các chức
năngđăngnhập,đăngxuấtvàbảomậttàikhoản.
23

| CHƯƠNG3.  | XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN |              |         |
| --------- | -------------------------------- | ------------ | ------- |
| 3.1.4 Đặc | tả chi tiết                      | các Use Case | cốt lõi |
Dưới đây là đặc tả chi tiết cho 03 hành động quan trọng nhất, thể hiện tính phối hợp
giữa các dịch vụ và các kịch bản xử lý ngoại lệ trong kiến trúc Microservices của hệ thống
job7189.
UseCase1:Ứngtuyểnviệclàm(JobApplication)
Môtảkịchbảnứngviênnộphồsơvàomộtvịtrícôngviệcđangmở.
| Thànhphần |     | Môtảchitiết                                    |     |
| --------- | --- | ---------------------------------------------- | --- |
| Tácnhân   |     | Ứngviên(Candidate).                            |     |
| Mụctiêu   |     | GửihồsơCVvàkhởitạođơnứngtuyểntạiHiringService. |     |
Tiềnđiềukiện Ứngviênđãđăngnhập;TintuyểndụngđangởtrạngtháiPUBLISHED.
| Luồngchính |     | 1.ỨngviênchọntệpCVvànhấnnút"Ứngtuyển". |     |
| ---------- | --- | -------------------------------------- | --- |
2.HệthốnglấyPresignedURLtừStorageServicevàtảifilelênMinIO.
3.CandidateServicelưuđườngdẫntệp(FilePath)vàtạoResumeID.
4.HiringServicegọisangJobServiceđểkiểmtratrạngtháitinđăng.
5.HệthốngtạobảnghiJobApplicationvàphátsựkiệntạođơnvàoKafka.
Luồngthaythế 4a. Nếu Job Service phản hồi tin đăng đã đóng (CLOSED) hoặc hết hạn: Hệ
thốngthôngbáolỗivàhủyquytrìnhứngtuyển.
2a. Nếu việc tải tệp lên MinIO thất bại: Thông báo lỗi kết nối và yêu cầu thử
lại.
Hậuđiềukiện Đơn ứng tuyển hiển thị trong danh sách của nhà tuyển dụng; Ứng viên nhận
emailxácnhận.
24

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
UseCase2:QuảnlýTintuyểndụng(JobPostingLifecycle)
Môtảquytrìnhsoạnthảovàgửiduyệtnộidungtinđăngcủanhàtuyểndụng.
Thànhphần Môtảchitiết
Tácnhân Nhàtuyểndụng(Recruiter).
Mụctiêu HoànthiệnnộidungJDvàchuyểntrạngtháisangchờphêduyệt.
Tiềnđiềukiện NhàtuyểndụngcóquyềnCREATE_JOBtrongWorkspacehiệntại.
Luồngchính 1.NhàtuyểndụngnhậpthôngtinJD(Tiêuđề,lương,yêucầu...).
2.Hệthốnglưubảnghivàobảngjob_jdsvớitrạngtháiDRAFT.
3.Nhàtuyểndụngnhấnnút"Gửiduyệt"(Submit).
4. Job Service chuyển trạng thái thành PENDING và khóa quyền chỉnh sửa nội
dung.
5.Hệthốngghinhậnlịchsửphiênbảnvàobảngjob_histories.
Luồngthaythế 3a. Nhà tuyển dụng chọn "Lưu tạm": Hệ thống giữ tin ở trạng thái DRAFT để
cóthểchỉnhsửasau.
4a. Nếu các thông tin bắt buộc bị thiếu: Hệ thống báo lỗi và yêu cầu bổ sung
trướckhiSubmit.
Hậuđiềukiện TintuyểndụngxuấthiệntrongdanhsáchchờduyệtcủaQuảntrịviên(Admin).
25

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
UseCase3:Dichuyểntrạngtháiứngviên(MoveCandidateStage)
MôtảkịchbảnnhàtuyểndụngđiềuphốiứngviênquacácvòngtuyểndụngtrênKanban.
Thànhphần Môtảchitiết
Tácnhân Nhàtuyểndụng(Recruiter).
Mụctiêu Cậpnhậtvòngtuyểndụngchoứngviênvàkíchhoạtthôngbáotựđộng.
Tiềnđiềukiện NhàtuyểndụngđangxembảngKanbancủamộttintuyểndụngcụthể.
Luồngchính 1.Nhàtuyểndụngkéothẻứngviêntừcộthiệntạisangcộttrạngtháimới.
2.HiringServicegọisangIdentityServicekiểmtraquyềnhạncủangườidùng.
3.HệthốngcậpnhậtStageIDmớivàocơsởdữliệu.
4.HiringServicephátsựkiệnapp.movedvàoMessageBroker.
5.CommunicationServicetiêuthụsựkiệnvàtựđộnggửiemailchoứngviên.
Luồngthaythế 2a. Nếu Identity Service phản hồi người dùng không có quyền (403
Forbidden): Hệ thống trả thẻ ứng viên về vị trí cũ và thông báo từ chối truy
cập.
5a.NếudịchvụEmailbịlỗi:SựkiệnvẫnđượclưutạiKafkađểxửlýlại(Retry)
saukhidịchvụphụchồi.
Hậuđiềukiện Trạngtháimớicủaứngviênđượcđồngbộhóatrêngiaodiệntấtcảngườidùng
liênquan.
26

| CHƯƠNG3. | XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN |     |     |     |     |     |
| -------- | -------------------------------- | --- | --- | --- | --- | --- |
Danhsáchvaitròvàchứcnăngtronghệthống
| Nhóm     | Vaitrò      | Môtảvaitrò            |          | Chứcnăngchính        |      |         |
| -------- | ----------- | --------------------- | -------- | -------------------- | ---- | ------- |
| Platform | SystemAdmin | Quảntrịtoànbộnềntảng, |          | Duyệt                |      | tin     |
|          |             | kiểm soát             | nội dung | và (Approve/Reject), |      | quản    |
|          |             | tenant                |          | lý danh              | mục, | quản lý |
Workspace
Workspace WorkspaceAdmin Quảntrịdoanhnghiệp Cấuhìnhcôngty,muagói
dịchvụ,phânquyền
|     | RecOps        | Thiết kế            | và tối ưu | quy Cấu hình       | pipeline,    | email |
| --- | ------------- | ------------------- | --------- | ------------------ | ------------ | ----- |
|     |               | trình               |           | template,scorecard |              |       |
|     | HiringManager | Chủsởhữunhucầutuyển |           | Tạo                | Requisition, | phê   |
|     |               | dụng                |           | duyệt              | kế hoạch,    | quyết |
địnhOffer
|     | Recruiter   | Vận hành         | quy trình | tuyển Sourcing, | đăng tin, | sàng     |
| --- | ----------- | ---------------- | --------- | --------------- | --------- | -------- |
|     |             | dụng             |           | lọchồsơ         |           |          |
|     | Coordinator | Điềuphốiphỏngvấn |           | Lên lịch        | phỏng     | vấn, sắp |
xếpphòng
|     | Interviewer | Đánhgiáứngviên |     | Tham | gia phỏng | vấn, |
| --- | ----------- | -------------- | --- | ---- | --------- | ---- |
|     |             |                |     | chấm | điểm      | bằng |
Scorecard
|     | Member | Thànhviênworkspace |     | Xemthôngtinnộibộ,giới |     |     |
| --- | ------ | ------------------ | --- | --------------------- | --- | --- |
thiệuứngviên(Referral)
| Public | Guest     | Người dùng           | chưa | đăng Xem tin | tuyển dụng, | tìm    |
| ------ | --------- | -------------------- | ---- | ------------ | ----------- | ------ |
|        |           | nhập                 |      | kiếmviệclàm  |             |        |
|        | Candidate | Ngườitìmviệcđãđăngký |      | Ứng tuyển,   | quản        | lý CV, |
theodõiđơn
|     | User | Tàikhoảnhệthốngcơbản |     | Quản | lý tài khoản, | đăng |
| --- | ---- | -------------------- | --- | ---- | ------------- | ---- |
nhậpSSO
| 3.1.5 Yêu | cầu phi chức | năng |     |     |     |     |
| --------- | ------------ | ---- | --- | --- | --- | --- |
Bên cạnh các yêu cầu nghiệp vụ, hệ thống còn phải đáp ứng các yêu cầu phi chức năng
nhằm đảm bảo khả năng vận hành ổn định, an toàn, mở rộng và hiệu quả trong môi trường
thựctế.Cácyêucầunàyđóngvaitrònềntảngchoviệclựachọnkiếntrúcvàcôngnghệtriển
khaihệthống.
1.Kiếntrúchệthống
HệthốngđượcthiếtkếtheomôhìnhMicroserviceskếthợpEvent-DrivenArchitecturenhằm:
27

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
• Táchbiệtcácchứcnăngnghiệpvụthànhcácdịchvụđộclập.
• Giảmsựphụthuộcchặtchẽgiữacácthànhphần.
• Tăngkhảnăngmởrộngvàkhảnăngbảotrì.
• Cho phép hệ thống phản ứng linh hoạt với các sự kiện nghiệp vụ phát sinh trong quá
trìnhvậnhành.
Mô hình Event-Driven giúp các dịch vụ giao tiếp bất đồng bộ thông qua các sự kiện, từ đó
giảmcouplingvàtăngkhảnăngchịutảicủatoànhệthống.
2.Bảomậtvàphânquyền
Authentication – Xác thực: Hệ thống sử dụng Keycloak như một Identity Provider (IdP)
trung tâm để quản lý danh tính người dùng. Keycloak chịu trách nhiệm: Xác thực người
dùng thông qua cơ chế Single Sign-On (SSO); Cấp phát các Token xác thực (Access Token,
RefreshToken,IDToken);Quảnlývòngđờiphiênđăngnhậpvàchínhsáchbảomật.
Authorization–Phânquyền:HệthốngápdụngmôhìnhTokenExchange/JWTEnrichment
nhằmtốiưuhóahiệunăngvàtăngtínhđộclậpcủacácMicroservice.Quytrìnhphânquyền
đượctổchứcnhưsau:IdentityServicechịutráchnhiệmtổnghợpvàđónggóitoànbộthông
tin Role và Permission của người dùng vào Access Token. Các Microservice nghiệp vụ khi
nhận request chỉ cần giải mã và kiểm tra Token để thực hiện Authorization Enforcement.
Việc kiểm tra quyền được thực hiện hoàn toàn Stateless, không yêu cầu truy vấn Database
haygọingượcvềIdentityService.
3.Bảomậtdữliệu
Đối với dữ liệu tập tin (CV, tài liệu ứng tuyển...), hệ thống áp dụng cơ chế Presigned URL
khi tải lên hoặc tải xuống file. Theo đó: Client chỉ được cấp quyền truy cập file trong thời
gian giới hạn; Không cho phép truy cập trực tiếp vào hệ thống lưu trữ; Giảm thiểu nguy cơ
ròrỉdữliệuvàtấncôngtráiphép.
4.Hiệunăng
Hệ thống được tối ưu hóa về độ trễ và khả năng xử lý tải lớn thông qua: Cơ chế Stateless
Authorization giúp kiểm tra quyền với độ trễ gần như bằng không; Giao tiếp bất đồng bộ
trongkiếntrúcEvent-Driven;KhảnăngmởrộnglinhhoạtcủacácMicroservice.
5.Tínhsẵnsàngvàđộtincậy
Hệ thống được triển khai trên nền tảng Kubernetes, cho phép: Tự động phát hiện lỗi và khởi
độnglạidịchvụgặpsựcố;Cânbằngtảigiữacácinstance;Mởrộnghoặcthuhẹptàinguyên
theonhucầusửdụng.
28

| CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN |         |      |          |
| ----------------------------------------- | ------- | ---- | -------- |
| 3.2 Thiết                                 | kế kiến | trúc | hệ thống |
Để trực quan hóa kiến trúc hệ thống từ mức tổng quan đến chi tiết, đồ án áp dụng mô
hìnhC4(Context,Containers,Components,Code).
| 3.2.1 Level | 1: Sơ | đồ ngữ cảnh | hệ thống |
| ----------- | ----- | ----------- | -------- |
Sơ đồ ngữ cảnh cung cấp cái nhìn tổng quan nhất về hệ thống Job7189, đặt nó vào trong
môi trường hoạt động thực tế và xác định các mối tương tác với người dùng và các hệ thống
bênngoài.
Hình3.4:Quyướckýhiệusửdụngtrongcácsơđồcủahệthống
Hình3.5:SơđồngữcảnhhệthốngcủahệthốngJob7189
1.Trungtâmhệthống:Job7189System
Job7189 là hệ thống phần mềm lõi được xây dựng nhằm hỗ trợ và tự động hóa toàn bộ quy
trình tuyển dụng cho doanh nghiệp. Trách nhiệm chính của Job7189 bao gồm: Quản lý tin
29

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
tuyển dụng; Tiếp nhận và xử lý hồ sơ ứng viên; Hỗ trợ sàng lọc, phỏng vấn, đánh giá; Quản
lýquytrìnhtheopipeline;Cungcấpbáocáothốngkê.
2.Ngườidùng(Users):
• InternalUsers:BaogồmcácvaitrònhưWorkspaceAdmin,Recruiter,HiringManager,
Interviewer. Họ tương tác với hệ thống để thực hiện các nhiệm vụ liên quan đến quy
trìnhtuyểndụngvàquảntrị.
• Public Users: Gồm Guest (người dùng chưa đăng nhập) và Candidate (ứng viên đã
đăngký).Họsửdụnghệthốngđểtìmkiếmviệclàmvànộphồsơứngtuyển.
• System Admin: Quản trị viên hệ thống chịu trách nhiệm quản lý toàn bộ nền tảng
Job7189,baogồmviệcduyệttintuyểndụng,quảnlýdanhmụcvàcấuhìnhhệthống.
3.Cáchệthốngbênngoài(ExternalSystems)
• Keycloak:IdentityProviderquảnlýđịnhdanhvàxácthực.Job7189ủyquyềnxácthực
choKeycloakquaOAuth2/OIDC.
• EmailService:SMTPServerdùngđểgửithưmờiphỏngvấn,thôngbáokếtquả.
• MinIO:ObjectStoragetươngthíchS3đểlưutrữCV,ảnhđạidiện,logoantoàn.
3.2.2 Level 2: Container Diagram (Sơ đồ Container)
KiếntrúcMicroservicesgiúphệthốnglinhhoạtvàmởrộngtốt.CácContainerchính:
• API Gateway (Kong): Điểm truy cập duy nhất. Trách nhiệm Routing, Authentication
(JWT),vàcácCross-CuttingConcerns(RateLimiting,CORS).
• WebApplication(SPA):FrontendxâydựngbằngNext.js,giaotiếpquaRESTfulAPI.
• Microservices Nghiệp vụ: Mỗi service sở hữu DB riêng. Bao gồm: Identity Service,
WorkspaceService,JobService,HiringService(ATSCore),CandidateService,Communication
ServicevàStorageService.
• DataStores:MySQL(lưutrữchính),Redis(Cachephântán),MinIO(ObjectStorage).
• MessageBroker(Kafka):Xươngsốngchogiaotiếpbấtđồngbộ,giúphệthốngloose
coupling(Vídụ:JobServicebắnsựkiệnjob.publishedđểcácservicekhácsubscribe).
30

| CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN |              |         |                   |
| ----------------------------------------- | ------------ | ------- | ----------------- |
| 3.2.3 Level                               | 2: Container | Diagram | (Sơ đồ Container) |
Ở cấp độ này, hệ thống Job7189 được phân rã thành các đơn vị triển khai độc lập. Để
quảnlýđộphứctạp,kiếntrúcđượctrìnhbàyqua03gócnhìntrọngtâm:
Gócnhìnnghiệpvụ(FunctionalView)
Tập trung vào luồng điều phối yêu cầu từ các ứng dụng Frontend qua API Gateway tới
cácdịchvụnghiệpvụvàcơchếgiaotiếpbấtđồngbộquaKafkaCluster.
Hình3.6:SơđồContainer-Gócnhìnluồngnghiệpvụ
Hình3.7:Chúgiảikýhiệugócnhìnnghiệpvụ
31

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
Gócnhìndữliệu(DataView)
Minh họa rõ nét mẫu thiết kế Database per Service. Mỗi Microservice sở hữu một kho
lưu trữ bền vững (MySQL) và một lớp đệm dữ liệu (Redis) riêng biệt, đảm bảo tính tự trị và
khảnăngmởrộngđộclập.
Hình3.8:SơđồContainer-Gócnhìnlưutrữdữliệu
Hình3.9:Chúgiảikýhiệugócnhìndữliệu
32

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
Gócnhìngiámsátvànhậtký(ObservabilityView)
ThểhiệnkiếntrúcCentralizedLoggingsửdụngbộcôngcụELK(Elasticsearch,Logstash/Filebeat,
Kibana).MỗiMicroserviceđượctíchhợpmộtSidecar(Filebeat)đểthuthậpnhậtkývậnhành
vàđẩyvềkhodữliệutậptrungElasticsearch.
Hình3.10:SơđồContainer-Gócnhìngiámsáthệthống
33

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
Hình3.11:Chúgiảikýhiệugócnhìngiámsát
3.2.4 Thiết kế chi tiết các dịch vụ nghiệp vụ (Microservices Design)
Dựa trên các yêu cầu nghiệp vụ và triết lý Microservices đã phân tích, hệ thống được
thiết kế với sự loại bỏ hoàn toàn các yếu tố trí tuệ nhân tạo (AI), tập trung vào tính ổn định
của dữ liệu thông qua công nghệ MySQL và khả năng mở rộng của hạ tầng hiện đại. Dưới
đâylàbảnthiếtkếchitiếtkiếntrúchệthốngMicroserviceschodựán.
Tổngquanhạtầngkỹthuật
Hệthốngsửdụngcácthànhphầnhạtầngtiêuchuẩnđểhỗtrợvậnhànhcácdịchvụphân
tán:
• IngressGateway(KongAPIGateway):MọiyêucầutừphíaClient(Web/Mobile)đều
phải đi qua Kong. Kong chịu trách nhiệm xác thực mã thông báo (Validation JWT),
điềuhướngyêucầu(Routing)vàgiớihạnlưulượng(RateLimiting).
• Message Broker (Apache Kafka): Đóng vai trò xương sống cho giao tiếp bất đồng
bộ,xửlýviệcgửiemail,thôngbáovàđồngbộtrạngtháidữliệugiữacácdịchvụ.
• Object Storage (MinIO): Sử dụng để lưu trữ các tệp tin vật lý như ảnh đại diện
(Avatar),hồsơứngviên(CVPDF/Docx).
• Database(MySQL):ÁpdụngmẫuthiếtkếDatabaseperService.Mỗidịchvụsởhữu
mộtcơsởdữliệuriêngbiệt,đảmbảotínhđónggóivàtựtrị.
• Cache (Redis): Mỗi dịch vụ được cấp một namespace/database riêng trên cụm Redis
chungđểlưutrữdữliệutạm,giúptốiưuhiệunăngtruyxuất.
3.2.5 Level 3: Component Diagram (Sơ đồ Thành phần)
Tạicấpđộnày,hệthốngJob7189được"zoomsâu"vàokiếntrúcnộitạicủatừngMicroservice.
Các dịch vụ được thiết kế tuân thủ mô hình Layered Architecture và kiến trúc Hexagonal,
giúptáchbiệthoàntoànlogicnghiệpvụ(Core)khỏicáctácnhânhạtầng(Infrastructure).
34

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
Dướiđâylàthiếtkếchitiếtvàphântíchthànhphầnchocácdịchvụtrọngtâm:
IdentityService-QuảnlýĐịnhdanh
Dịchvụđóngvaitròxácthựctậptrungvàquảnlýhồsơngườidùng.
• JwtMiddleware: Thành phần then chốt thực hiện kiểm tra chữ ký số của Token từ
KeycloaktrướckhichophépyêucầuđivàolớpController.
• KeycloakSyncWorker: Một Worker chạy ngầm thực hiện nhiệm vụ đồng bộ dữ liệu
người dùng mới từ Keycloak về MySQL nội bộ để đảm bảo tính nhất quán dữ liệu
(Dataconsistency).
• IdentityRedis:LưutrữCachehồsơngườidùngđểgiảmtảichoDatabasechính.
Hình3.12:SơđồthànhphầnIdentityService
35

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
WorkspaceService-QuảnlýKhônggianlàmviệc
Điềuphốicấutrúctổchứcvàluồngmờithànhviênthamgiadoanhnghiệp.
• WorkspaceService:Chứalogicnghiệpvụvềphânquyềnvàgiớihạnsửdụngcủatừng
tổchức.
• InvitationPublisher:ThànhphầnKafkaProducerchịutráchnhiệmbắnsựkiệninvitation.created
đểkíchhoạtdịchvụthôngbáogửiemailmời.
Hình3.13:SơđồthànhphầnWorkspaceService
36

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
JobService-QuảnlýTintuyểndụng
QuảnlývòngđờiphứctạpcủatintuyểndụngthôngquacơchếStateMachine.
• JobStateMachine: Thành phần quản lý logic chuyển trạng thái (Draft → Pending →
Published),đảmbảotínhvẹntoànnghiệpvụ.
• PublicJobController:Đượctốiưuhóađểphụcvụcácyêucầutruyvấntintuyểndụng
côngkhaitừphíaứngviên.
Hình3.14:SơđồthànhphầnJobService
37

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
HiringService-QuảnlýQuytrìnhTuyểndụng(ATSCore)
Dịchvụtrọngtâmxửlýhồsơvàcácgiaiđoạntuyểndụng.
• WorkflowService:Điềuphốiluồngdichuyểnứngviênquacácvòng(MoveStage).
• JobStatusConsumer: Lắng nghe sự kiện job.closed từ Kafka để tự động thực hiện
cáchànhđộngđónghồsơứngviêntươngứng.
Hình3.15:SơđồthànhphầnHiringService
38

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
CandidateService-QuảnlýHồsơỨngviên
Lưutrữvàtươngtácvớitàisảnsốcủangườitìmviệc.
• JobServiceClient: Một HTTP Client nội bộ dùng để gọi sang Job Service lấy thông
tinbổtrợkhiứngviênxemlạicáctinđãlưu(SavedJobs).
• ResumeService: Xử lý logic nghiệp vụ liên quan đến đường dẫn file CV và metadata
ứngviên.
Hình3.16:SơđồthànhphầnCandidateService
39

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
CommunicationService-HệthốngGiaotiếp
Xửlýthôngbáovàkênhchatnộibộdoanhnghiệp.
• NotificationConsumer:LắngnghemọisựkiệncầngửithôngbáotừKafkaCluster.
• EmailSenderService: Tích hợp với hệ thống SMTP bên ngoài để thực hiện gửi thư
điệntửdựatrêncácTemplateđãcấuhìnhsẵn.
Hình3.17:SơđồthànhphầnCommunicationService
40

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
StorageService-DịchvụLưutrữtệptin
LớptrừutượnghóatươngtácvớihệthốngObjectStorage(MinIO).
• MinIOService:TíchhợptrựctiếpvớiSDKcủaMinIOđểthựchiệncấpphátPresigned
URL vàquảnlýtệptin.
Hình3.18:SơđồthànhphầnStorageService
41

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
3.2.6 Thiết kế chi tiết hạ tầng và Vận hành
Hệ thống loại bỏ hoàn toàn các yếu tố trí tuệ nhân tạo (AI) để tập trung vào tính ổn định
caocủacơsởdữliệuMySQLvàkhảnăngmởrộngcủakiếntrúcMicroserviceshiệnđại.
Tổngquanhạtầngkỹthuật
Hệthốngsửdụngcácthànhphầnhạtầngtiêuchuẩnđểhỗtrợvậnhànhcácdịchvụphân
tán:
• IngressGateway(KongAPIGateway):ĐiểmchạmduynhấtchomọiyêucầuClient,
xửlýRoutingvàJWTValidation.
• Message Broker (Apache Kafka): Xương sống cho giao tiếp bất đồng bộ, giúp hệ
thốngđạttrạngtháiEventuallyConsistent.
• ObjectStorage(MinIO):Lưutrữtệptinvậtlý(Avatar,CV).
• Caching (Redis): Mỗi dịch vụ sở hữu 01 instance hoặc namespace Redis riêng để tối
ưutốcđộđọc.
LợiíchcủaphươngphápthiếtkếComponent
Việcphânrãthànhcácthànhphần(Components)rõrànggiúphệthốngđạtđược:
• TínhTựtrị(Autonomy):ThayđổilogictrongJobStateMachinekhônglàmảnhhưởng
đếncácdịchvụkhác.
• Tính Chịu lỗi (Resilience): Nếu EmailSenderService gặp sự cố, Kafka vẫn lưu giữ
cácsựkiệnthôngbáođểxửlýlạikhidịchvụphụchồi.
• TínhHiệunăng:SửdụngSidecar(Filebeat)vàRedisgiúpgiảmthiểuđộtrễchongười
dùngcuối.
3.2.7 Thiết kế mô hình triển khai (Deployment Diagram)
Hệ thống triển khai trên nền tảng Kubernetes (K8s) nhằm đảm bảo khả năng sẵn sàng
cao(HighAvailability)vàtựđộnghồiphục(Self-healing).
• KubernetesCluster:QuảnlýtàinguyêntrongNamespacejob7189-ns.
• App Pods: Các Microservices được triển khai dưới dạng Deployment với tối thiểu 02
replicas.
• Persistent Volumes (PVC): Đảm bảo dữ liệu của MySQL, Kafka và MinIO được lưu
trữbềnvững.
42

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
3.3 Thiết kế chi tiết giao tiếp và dữ liệu
3.3.1 Thiết kế Cơ sở dữ liệu phân tán
Hệ thống tuân thủ nghiêm ngặt mô hình Database per Service, trong đó mỗi dịch vụ
quảnlýmộtcơsởdữliệuđộclậpvớitiềntốhệthốnglàjob7189_.Việcsửdụngcơchếkhóa
chínhUUIDv7xuyênsuốtgiúpđảmbảotínhduynhấttoàncục,hỗtrợsắpxếptheothờigian
vàtăngcườngtínhbảomậtchodữliệuphântán.
Dướiđâylàbảntrìnhbàychitiếtcấutrúccácthựcthểdữliệudựatrênsơđồthiếtkế:
CơsởdữliệuỨngviênvàGiaotiếp
Sự kếthợp nàyquản lýluồng dữliệu đầuvào từứng viênvà các tươngtác thờigian thực
tronghệthống.
• job7189_candidate_db: Lưu trữ hồ sơ ứng viên thông qua thực thể candidates, quản
lýtệptinCVquabảngresumesvàtheodõihànhviứngviêntạibảnginteractions.
• job7189_communication_db: Được thiết kế theo cấu trúc phòng chat hiện đại. Bảng
con_conversationsvàcon_conversation_participantsquảnlýnhómngườidùng,trong
khi con_messages lưu trữ nội dung tin nhắn. Đặc biệt, bảng email_logs giúp theo dõi
trạngtháigửithôngbáohệthốngđểđảmbảođộtincậycủaluồnggiaotiếp.
Hình3.19:Lượcđồcơsởdữliệujob7189_candidate_dbvàjob7189_communication_db
43

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
CơsởdữliệuĐịnhdanhvàTuyểndụng
Đây là hai kho dữ liệu đóng vai trò cốt lõi trong việc vận hành định danh và quy trình
ATS.
• job7189_identity_db:Quảnlýcácthôngtintàikhoảnngườidùngvàhồsơchitiếtcủa
nhà tuyển dụng (profiles), đóng vai trò là nguồn dữ liệu chuẩn cho các dịch vụ khác
thamchiếuthôngtincánhân.
• job7189_hiring_db: Lưu trữ logic quản lý ứng viên. Cấu trúc thực thể tập trung vào
recruitment_pipelinesđểđịnhnghĩaquytrìnhvàjob_applicationsđểquảnlýđơnứng
tuyểntạitừngpipeline_stagescụthể.
Hình3.20:Lượcđồcơsởdữliệujob7189_identity_dbvàjob7189_hiring_db
44

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
CơsởdữliệuTintuyểndụng
Cơ sở dữ liệu này có độ chi tiết và cấu trúc rất cao (tall-structure), chịu trách nhiệm bao
quáttoànbộthôngtinnghiệpvụvềtinđăngtuyểndụng.
• Cơ chế Draft-Live: Sử dụng hai bảng chính job_jds và job_sub_jds để tách biệt tin
đang soạn thảo và tin đã công bố công khai, đảm bảo tính vẹn toàn dữ liệu trong suốt
quátrìnhkiểmduyệt.
• Thôngtinchitiếtnghiệpvụ:Hệthốnglưutrữcựckỳchitiếtcácyêucầuvềkỹnăng
(TechnicalSkill,SoftSkill),mứclương,độtuổi,vàvịtríđịalý.
• Hệ thống Master Data: Tích hợp các bảng danh mục như job_sectors, job_types,
job_workingtypesđểchuẩnhóadữliệuđầuvào.
• Thốngkêthờigianthực:Bảngjob_statsghinhậntrựctiếplượtxemvàlượtứngtuyển
đểphụcvụbáocáoquảntrị.
Hình3.21:Lượcđồcơsởdữliệujob7189_job_dbvớicấutrúcthôngtinchitiết
45

| CHƯƠNG3. | XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN |     |     |     |     |     |     |
| -------- | -------------------------------- | --- | --- | --- | --- | --- | --- |
CơsởdữliệuKhônggianlàmviệc
Đây là kho dữ liệu quản lý mô hình đa người thuê (Multi-tenancy) với cấu trúc phân
quyềnchặtchẽ.
• QuảnlýTenant:Thựcthểworkspacesquảnlýthôngtintổchức,liênkếtvớijob_companies
đểhiểnthịthươnghiệunhàtuyểndụng.
• Phân quyền Bitmask: Bảng workspace_members sử dụng các trường dữ liệu kiểu
bigint cho quyền hạn (workspace_permissions, job_permissions,...), cho phép lưu trữ
hàng chục quyền hạn chi tiết trong một trường dữ liệu duy nhất, giúp tối ưu hóa hiệu
năngkiểmtraquyềntạitầngMicroservices.
| Quản | lý lời mời: |      | workspace_invitations |     |             |               |       |
| ---- | ----------- | ---- | --------------------- | --- | ----------- | ------------- | ----- |
| •    |             | Thực | thể                   |     | quản lý quy | trình mở rộng | thành |
viênthôngquaTokenvàmãxácnhậnvớithờigianhếthạnnghiêmngặt.
3.3.2 Đặc tả giao diện lập trình ứng dụng (API Specifications)
Hệ thống được thiết kế theo kiến trúc RESTful API, sử dụng định dạng dữ liệu JSON
để trao đổi thông tin. Các Endpoint được phân tách theo trách nhiệm nghiệp vụ của từng
Microservice và tuân thủ mô hình phân quyền RBAC phẳng (Flat RBAC) đã định nghĩa tại
sơđồUseCase.
DịchvụĐịnhdanh(IdentityService)
Dịch vụ này chịu trách nhiệm quản lý thông tin hồ sơ và trạng thái tài khoản. Các chức
năngtậptrungvàoviệcchophépngườidùngtựquảnlýthôngtinvàAdminkiểmsoátquyền
truycậphệthống.
Bảng3.2:ĐặctảAPIcủaIdentityService
| Method | URI                 |     |     | Vaitrò | Môtảchứcnăng |              |        |
| ------ | ------------------- | --- | --- | ------ | ------------ | ------------ | ------ |
| GET    | /recruiters/profile |     |     | User   | Xem          | thông tin hồ | sơ làm |
việccánhân.
| PUT | /recruiters/profile |     |     | User | Cập | nhật chức danh, | phòng |
| --- | ------------------- | --- | --- | ---- | --- | --------------- | ----- |
ban,thôngtinliênlạc.
| GET | /candidates/profile |     |     | Candidate | Xem | hồ sơ cá nhân | ứng |
| --- | ------------------- | --- | --- | --------- | --- | ------------- | --- |
viên.
| GET | /admin/users |     |     | SystemAdmin | Lấy | danh sách toàn | bộ  |
| --- | ------------ | --- | --- | ----------- | --- | -------------- | --- |
ngườidùnghệthống.
PATCH /admin/users/{id}/status SystemAdmin Thực hiện khóa (Ban) hoặc
mởkhóangườidùng.
46

| CHƯƠNG3. | XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN |     |     |     |
| -------- | -------------------------------- | --- | --- | --- |
DịchvụKhônggianlàmviệc(WorkspaceService)
Quản lý mô hình đa người thuê (Multi-tenancy), cho phép các doanh nghiệp vận hành
độclậptrêncùngmộtnềntảnghạtầng.
Bảng3.3:ĐặctảAPIcủaWorkspaceService
| Method | URI | Vaitrò | Môtảchứcnăng |     |
| ------ | --- | ------ | ------------ | --- |
POST
|     | /workspaces | User | Khởi tạo | công ty mới  |
| --- | ----------- | ---- | -------- | ------------ |
|     |             |      | (người   | tạo mặc định |
làAdmin).
| PUT | /workspaces/{id} | WsAdmin | Cập nhật | thông tin |
| --- | ---------------- | ------- | -------- | --------- |
thươnghiệucôngty.
| GET | /workspaces/{id}/members | Member | Xem danh | sách thành |
| --- | ------------------------ | ------ | -------- | ---------- |
viênthuộctổchức.
| POST | /workspaces/{id}/invitations | WsAdmin | Quản     | lý nhân sự  |
| ---- | ---------------------------- | ------- | -------- | ----------- |
|      |                              |         | qua việc | gửi lời mời |
email.
| PUT | /workspaces/{id}/members | WsAdmin | Phân        | định vai trò |
| --- | ------------------------ | ------- | ----------- | ------------ |
|     |                          |         | (Recruiter, | Coord...)    |
choMember.
DELETE /workspaces/{id}/members/{uid} WsAdmin Xóa thành viên khỏi
khônggianlàmviệc.
DịchvụTintuyểndụng(JobService)
Quảnlýluồngtinđăngtừlúckhởitạonhápđếnkhikiểmduyệtvàcôngbốcôngkhai.
47

| CHƯƠNG3. | XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN |     |     |     |
| -------- | -------------------------------- | --- | --- | --- |
Bảng3.4:ĐặctảAPIcủaJobService
| Method | URI | Vaitrò | Mô tả | chức |
| ------ | --- | ------ | ----- | ---- |
năng
| POST | /workspaces/{wsId}/jobs | Recruiter | Quản | lý tin |
| ---- | ----------------------- | --------- | ---- | ------ |
tuyển dụng
(TạoDraft).
| PUT | /workspaces/{wsId}/jobs/{id} | Recruiter | Chỉnh    | sửa  |
| --- | ---------------------------- | --------- | -------- | ---- |
|     |                              |           | nội dung | JD   |
|     |                              |           | (chỉ khi | đang |
ởDraft).
| PATCH | /workspaces/{wsId}/jobs/{id}/submit | Recruiter | Chuyển |      |
| ----- | ----------------------------------- | --------- | ------ | ---- |
|       |                                     |           | trạng  | thái |
|       |                                     |           | sang   | chờ  |
phê duyệt
(Pending).
| GET | /admin/jobs | SystemAdmin | Xem      | danh |
| --- | ----------- | ----------- | -------- | ---- |
|     |             |             | sách các | tin  |
|     |             |             | đăng     | đang |
chờ kiểm
duyệt.
| PATCH | /admin/jobs/{id}/approve | SystemAdmin | Phê duyệt | để     |
| ----- | ------------------------ | ----------- | --------- | ------ |
|       |                          |             | công      | bố tin |
|       |                          |             | lên sàn   | việc   |
|       |                          |             | làm       | công   |
khai.
| GET | /public/jobs | Guest | Tìm  | kiếm |
| --- | ------------ | ----- | ---- | ---- |
|     |              |       | việc | làm  |
|     |              |       | công | khai |
(kèm lọc/sắp
xếp).
48

| CHƯƠNG3. | XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN |     |     |     |     |
| -------- | -------------------------------- | --- | --- | --- | --- |
DịchvụTuyểndụng(HiringService-ATS)
Đây là dịch vụ phức tạp nhất, điều phối các vai trò chuyên biệt trong quy trình đánh giá
ứngviên.
Bảng3.5:ĐặctảAPIcủaHiringService
| Method | URI |     | Vaitrò | Môtảchứcnăng |     |
| ------ | --- | --- | ------ | ------------ | --- |
PUT
|     | /workspaces/{wsId}/pipelines/{id} |     | RecOps | Thiết kế | quy trình |
| --- | --------------------------------- | --- | ------ | -------- | --------- |
(Pipeline/Stages)
choJob.
| GET | /board/{jobId} |     | HiringMgr | Quản lý  | ứng viên |
| --- | -------------- | --- | --------- | -------- | -------- |
|     |                |     |           | qua giao | diện     |
Kanbantậptrung.
| POST | /applications/{appId}/move |     | Recruiter | Thực hiện | kéo-thả  |
| ---- | -------------------------- | --- | --------- | --------- | -------- |
|      |                            |     |           | ứng viên  | sang các |
vòngtiếptheo.
| POST | /interviews |     | Coordinator | Thiết lập | thời gian |
| ---- | ----------- | --- | ----------- | --------- | --------- |
|      |             |     |             | và nhân   | sự phỏng  |
vấnứngviên.
POST
|     | /scorecards |     | Interviewer | Đánh giá | và chấm |
| --- | ----------- | --- | ----------- | -------- | ------- |
điểmứngviêndựa
trênScorecard.
| GET | /applications/{id}/scorecards |     | HiringMgr | Xem báo  | cáo tổng  |
| --- | ----------------------------- | --- | --------- | -------- | --------- |
|     |                               |     |           | hợp đánh | giá để ra |
quyếtđịnh.
DịchvụỨngviênvàTiệních(Candidate&StorageService)
QuảnlýtàisảnsốcủaứngviênvàhạtầnglưutrữtệptinvậtlýtạiMinIO.
Bảng3.6:ĐặctảAPICandidatevàStorageService
| Method | URI      | Vaitrò    | Môtảchứcnăng             |     |     |
| ------ | -------- | --------- | ------------------------ | --- | --- |
| POST   | /resumes | Candidate | QuảnlýhồsơCV(lưumetadata |     |     |
saukhiupload).
POST /jobs/{jobId}/apply Candidate Thực hiện nộp đơn ứng tuyển
vàovịtrícôngviệc.
POST /interactions/saved-jobs Candidate Thực hiện lưu (Bookmark) tin
tuyểndụngyêuthích.
| POST | /presigned-url | User | Lấy URL | upload trực | tiếp tới |
| ---- | -------------- | ---- | ------- | ----------- | -------- |
MinIO(giảmtảiGateway).
49

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
PhântíchtínhnhấtquángiữaAPIvàBiểuđồUseCase
Thiết kế hệ thống đảm bảo sự tương quan 1-1 giữa các "bong bóng"hành động trong sơ
đồ Use Case và các Endpoint API thực tế. Việc áp dụng mô hình phân vai rạch ròi mang lại
nhữngđặcđiểmsau:
• Phânđịnhtráchnhiệm(RoleIsolation):API/pipelineschỉdànhchoRecOpsđể
thiết kế quy trình, trong khi /move ứng viên chỉ dành cho Recruiter. Điều này khớp
hoàn toàn với việc tách biệt Actor trên sơ đồ Use Case, đảm bảo tính khách quan và
chuyênmônhóatrongquytrìnhtuyểndụng.
• Thựcthiquyềnhạn(AuthorizationEnforcement):APIPOST /scorecardsđòihỏi
vai trò Interviewer. Trong mã nguồn, hệ thống thực hiện kiểm tra stateless dựa trên
JWT để xác nhận người dùng có quyền chấm điểm tại một buổi phỏng vấn cụ thể hay
không.
• Kế thừa quyền cơ bản: Mọi thành viên trong tổ chức đều có vai trò Member, cho
phéphọgọicácAPInhưGET /membershoặcGET /jobs(nộibộ),tươngứngvớiUse
case"Xemtintuyểndụngnộibộ".
• Quản trị toàn cục: Tác nhân System Admin nằm ngoài phạm vi Workspace, tương
tác với Identity Service và Job Service để thực hiện các Use case "Kiểm duyệt Tin
đăng" và"QuảnlýWorkspace".
Cách tiếp cận này không chỉ giúp hệ thống bảo mật hơn mà còn hỗ trợ việc bảo trì, nâng
cấp các logic nghiệp vụ của từng dịch vụ mà không gây ảnh hưởng đến các thành phần khác
trongkiếntrúcMicroservices.
3.3.3 Biểu đồ tuần tự liên dịch vụ (Cross-service Sequence Diagram)
TrongkiếntrúcMicroservices,việcthựchiệnmộtquytrìnhnghiệpvụthườngđòihỏisự
phốihợpcủanhiềudịchvụkhácnhau.Hệthốngjob7189sửdụnghaiphươngthứcgiaotiếp
chính: giao tiếp đồng bộ qua REST API cho các tác vụ cần phản hồi tức thời và giao tiếp
bấtđồngbộquaMessageBroker(Kafka)chocáctácvụtốnthờigianhoặccầnđảmbảotính
lỏnglẻo(loosecoupling).
Cáctươngtácdịchvụtrựctiếp(SynchronousCommunication)
Dưới đây là bảng tổng hợp các luồng giao tiếp đồng bộ giữa các dịch vụ nội bộ nhằm
phụcvụcáclogicnghiệpvụcầnkiểmtradữliệutứcthì.
50

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
Bảng3.7:CáctươngtácđồngbộgiữacácMicroservices
STT ServiceGọi ServiceNhận Mụcđíchnghiệpvụ
1 Workspace Identity XácthựcEmailtồntạivàlấyđịnhdanhngườidùng
(user_id)khithêmthànhviên.
2 Job Identity Truyxuấtthôngtinchitiết(Tên,Avatar)củangười
đăngtinđểhiểnthịtrênJD.
3 Hiring Job Kiểm tra sự tồn tại và trạng thái PUBLISHED của
tintuyểndụngtrướckhichophépứngtuyển.
4 Hiring Candidate Lấy thông tin liên lạc và đường dẫn hồ sơ CV từ
CandidateServiceđểhiểnthịtrongATS.
5 Frontend Storage Lấy Presigned URL để tải trực tiếp tệp tin lên
MinIOmàkhôngcầnthôngquahệthốngBackend.
Cácsựkiệnhướngđốitượng(AsynchronousCommunicationviaKafka)
Các dịch vụ trao đổi thông điệp thông qua các Topic trên Kafka. Phương thức này giúp
hệthốnghoạtđộngổnđịnhkểcảkhimộtdịchvụthànhphầngặpsựcố.
51

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
Bảng3.8:Danhsáchcácsựkiện(Events)traođổigiữacácdịchvụ
| STT Producer | Sựkiện       | Consumer | Hànhđộngxửlý           |           |            |
| ------------ | ------------ | -------- | ---------------------- | --------- | ---------- |
| 1 Identity   | user.created | Comm     | ĐồngbộthôngtinánhxạID- |           |            |
|              |              |          | Email                  | vào Redis | để phục vụ |
gửithưsaunày.
2 Identity user.updated Workspace,Job Cập nhật lại Cache thông tin
|     |     |     | người | dùng trong | danh sách |
| --- | --- | --- | ----- | ---------- | --------- |
thànhviên/ngườiđăng.
| 3 Workspace | invite.created | Comm | Kíchhoạtquytrìnhgửiemail |     |     |
| ----------- | -------------- | ---- | ------------------------ | --- | --- |
mờithamgiakhônggianlàm
việc.
| 4 Job | job.published | Comm | Gửi email  | thông báo | cho nhà  |
| ----- | ------------- | ---- | ---------- | --------- | -------- |
|       |               |      | tuyển dụng | tin đã    | được phê |
duyệtthànhcông.
| 5 Job | job.published | SearchWorker | ĐẩydữliệuvàoElasticsearch |     |     |
| ----- | ------------- | ------------ | ------------------------- | --- | --- |
giúpứngviêncóthểtìmkiếm
tintứcthời.
| 6 Job | job.closed | Hiring | Tự động | đóng/từ     | chối các hồ |
| ----- | ---------- | ------ | ------- | ----------- | ----------- |
|       |            |        | sơ đang | chờ đối với | tin tuyển   |
dụngđãđóng.
| 7 Hiring | app.created | Comm | Gửi email | xác nhận | nộp đơn |
| -------- | ----------- | ---- | --------- | -------- | ------- |
thànhcôngchoứngviên.
| 8 Hiring | app.moved | Comm | Gửi thông  | báo kết | quả vòng   |
| -------- | --------- | ---- | ---------- | ------- | ---------- |
|          |           |      | tuyển dụng | (Mời    | phỏng vấn, |
Thưcảmơn).
| 9 Hiring | intw.scheduled | Comm | Gửi lịch | phỏng vấn | kèm link |
| -------- | -------------- | ---- | -------- | --------- | -------- |
|          |                |      | họp trực | tuyến cho | các bên  |
liênquan.
Cácluồngnghiệpvụđiểnhình(CoreSequenceFlows)
Dưới đây là mô tả chi tiết các bước xử lý cho hai quy trình cốt lõi thể hiện tính phối hợp
củakiếntrúcphântán.
Kịchbản1:Tảihồsơứngviên(UploadCV)
1. Frontend gửi yêu cầu tới Storage Service để lấy URL tải lên có chữ ký (Presigned
URL).
52

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
2. StorageServicephảnhồiURLantoàntrỏtrựctiếptớiMinIO.
3. Frontend thực hiện đẩy tệp PDF trực tiếp lên MinIO bằng URL được cấp, giảm tải
hoàntoànbăngthôngchocácAPInghiệpvụ.
4. Sau khi upload xong, Frontend gửi yêu cầu POST /resumes kèm đường dẫn tệp
(FilePath)tớiCandidateServiceđểlưutrữthôngtinhồsơvàocơsởdữliệu.
Hình3.22:Biểuđồtuầntựluồngtảihồsơứngviên
Kịchbản2:Dichuyểnứngviêntrongquytrìnhtuyểndụng(ATSPipeline)
1. Nhà tuyển dụngthực hiện kéo-thả ứng viên trên giao diện Kanban, ứng dụng gửi yêu
cầuPOST /applications/{id}/movetớiHiringService.
2. Hiring Service thực hiện cập nhật trạng thái vòng tuyển dụng mới (StageID) vào
job7189_hiring_db.
3. HiringServicephátsựkiệnapplication.stage_movedvàohệthốngKafka.
4. Hệthốngphảnhồi200OKngaylậptứcchongườidùngđểđảmbảotốcđộgiaodiện.
5. Tạitiếntrìnhchạyngầm,CommunicationService(Consumer)nhậnđượcsựkiện,tự
độngsoạnnộidungdựatrênTemplatevàgửiemailthôngbáotớiứngviên.
53

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
Hình3.23:Biểuđồtuầntựluồngdichuyểnứngviênquacácvòng
3.3.4 Cấu hình hạ tầng thực nghiệm
Bàilàmcủaemcóđẩylênlinkgithub:https://github.com/pTBgH/doan2.git
CấuhìnhAPIGateway(Kong)
Hệ thống sử dụng Kong làm cổng chào duy nhất. Cấu hình được triển khai qua tệp
kong.yml định nghĩa các Service và Route. Hình 3.24 minh họa kết quả cấu hình các
EndpointnghiệpvụđãđượcánhxạthànhcôngvàoGateway.
3.3.5 Kết quả triển khai Backend
QuátrìnhkiểmthửBackendđượcthựchiệnthôngquacôngcụPostman.Tạiđây,biếnmôi
trườngbaseURLđượcthiếtlậptrỏtớiđịachỉcủaKongGateway(vídụ:http://api.job7189.local).
MọiyêucầunghiệpvụđềuyêucầuxácthựcthôngquacơchếBearerToken.Hệthốngsử
dụng Access Token (JWT) được cấp phát từ Keycloak để đính kèm vào Header của request.
Kong chịu trách nhiệm giải mã, kiểm tra chữ ký và thời hạn của Token trước khi cho phép
yêucầuđitớicácMicroservicesbêntrong.
Dướiđâylàkếtquảkiểmthửluồngvòngđờitintuyểndụng:
Kiểmthửquytrìnhphêduyệttintuyểndụng(ApproveJob)
Hình 3.25 minh họa kết quả khi System Admin thực hiện phê duyệt một tin tuyển dụng
đangởtrạngtháiPENDING.
Phântíchkếtquả:
54

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
Hình3.24:CácRoutenghiệpvụđượcđịnhtuyếnquaKongGateway
Hình3.25:KếtquảkiểmthửAPIPhêduyệttinđăng(AdminApprove)
55

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
• Mã phản hồi: 200 OK, phản hồi trong thời gian 304ms, cho thấy hiệu năng xử lý ổn
địnhquaGateway.
• Định danh duy nhất: Trường job_id có giá trị 019b9f13... minh chứng cho việc
sử dụng cấu trúc UUIDv7, giúp tối ưu hóa việc lưu trữ và sắp xếp trong cơ sở dữ liệu
phântán.
• Chuyển đổi trạng thái: Trường status đã chuyển từ Pending sang Published, xác
nhậnlogictạiJobServiceđãthựchiệnthànhcông.
• Tính nhất quán: Các trường thống kê (view_count, apply_count) được khởi tạo
bằng 0, sẵn sàng cho việc ghi nhận tương tác từ ứng viên. Bên cạnh đó, slug chỉ khởi
tạojobđãđượcduyệtnhằmtốiưuCEO.
KiểmthửcácgiaiđoạnDraftvàSubmit
Các giai đoạn khởi tạo ban đầu cũng được đồng bộ. Nhà tuyển dụng thực hiện tạo tin
(Draft)vàgửiduyệt(Submit)thôngquacácphươngthứcPOSTvàPATCHtươngứng.
(a)Tạobảnnháptinđăng(Draft) (b)Gửiduyệttinđăng(Submit)
Hình3.26:Kếtquảkiểmthửcáctrạngtháikhởitạotintuyểndụng
3.4 Kết luận chương 3
Chương 3 đã trình bày toàn bộ quy trình xây dựng hệ thống Job7189, từ bước phân tích
nghiệpvụ,môhìnhhóaquytrình(BPMN,UseCase)đếnthiếtkếvàhiệnthựchóakiếntrúc
MicroserviceschitiếttheomôhìnhC4.
Kết quả triển khai cho thấy hệ thống đã vận hành ổn định trên hạ tầng Kubernetes, giải
quyết bài toán phân tán dữ liệu và giao tiếp bất đồng bộ. Đây là minh chứng cho tính đúng
đắn của các nguyên lý thiết kế đã đề cập tại Chương 2, đồng thời là cơ sở quan trọng để đưa
racácđánhgiátổngthểvàhướngpháttriểntrongphầnkếtluậncuốicùng.
56

Kết luận
Sau thời gian nghiên cứu và triển khai thực nghiệm đề tài "Kiến trúc Microservice và
Ứng dụng trong Xây dựng Hệ thống tuyển dụng", đồ án đã hoàn thành các mục tiêu cốt
lõivềmặtnghiêncứukiếntrúcvàxâydựngnềntảnghệthống.Dướiđâylàcáckếtquảchính
đạtđược:
Vềmặtlýthuyếtvàkiếntrúc:
• Đồ án đã làm chủ được phương pháp luận Thiết kế hướng miền (Domain-Driven
Design) để phân rã một hệ thống nghiệp vụ phức tạp thành 07 Microservices độc lập,
đảmbảotínhliênkếtlỏng(LooseCoupling)vàtínhtựtrịcao(HighAutonomy).
• Thiếtlậpthànhcôngcácmẫuthiếtkếnềntảngchomộthệthốngphântánchuẩncông
nghiệp bao gồm: API Gateway, Centralized Authentication (Keycloak), Event-Driven
Architecture(Kafka)vàDatabaseperService.
Vềmặtthựcnghiệmvàtriểnkhai:
• Xâydựngthànhcôngkhungxương(SkeletalSystem)chohệthốngBackendvớiđầyđủ
cácdịchvụ:Identity,Workspace,Job,Hiring,Candidate,StoragevàCommunication.
• Mặcdùtrongphạmvithựcnghiệm,đồánmớichỉtậptrunghiệnthựchóamộtphần
cácAPInghiệpvụcốtlõi(nhưluồngĐăngtin,DuyệttinvàChuyểnvòngứngtuyển),
nhưng toàn bộ cấu trúc mã nguồn đã được chuẩn hóa theo kiến trúc lớp (Layered
Architecture).
• Khảnăngpháttriểnnhanh(RapidDevelopment):Vớiviệcđãthiếtlậpsẵnhạtầng
Gateway, cơ chế xác thực tập trung và các thư viện dùng chung cho giao tiếp Kafka,
việc bổ sung thêm các API nghiệp vụ mới hiện nay chỉ đòi hỏi tập trung vào Logic
Domain mà không cần quan tâm đến các vấn đề hạ tầng phức tạp. Điều này cho phép
các đội ngũ phát triển có thể làm việc song song và đưa tính năng ra thị trường một
cáchthầntốc.
57

CHƯƠNG3. XÂYDỰNGHỆTHỐNGTUYỂNDỤNGTRỰCTUYẾN
• Tối ưu hóa việc xử lý tệp tin thông qua giải pháp Presigned URL với MinIO và hệ
thốnggiámsátnhậtkýtậptrungvớiElasticsearch/Kibana,đảmbảohệthốngsẵnsàng
choviệcvậnhànhthựctế.
Hạnchếvàhướngpháttriển:
• Hạn chế: Do giới hạn về thời gian, hệ thống chưa phủ hết 100% các API phụ trợ và
cáckịchbảnkiểmthửtải(LoadTest)ởquymôcựclớn.
• Hướngpháttriển:HoànthiệnnốtdanhsáchcácAPIcònlạidựatrênkhungkiếntrúc
đãcó;TriểnkhaihệthốnglênmôitrườngKuberneteshoànchỉnhvàtíchhợpthêmcác
côngnghệAIđểtựđộnghóaviệcsànglọchồsơdựatrêndữliệuđãđượccấutrúchóa
tốttạitừngService.
Tómlại,đồánđãchứngminhđượctínhđúngđắncủaviệclựachọnkiếntrúcMicroservices
cho bài toán tuyển dụng. Kết quả quan trọng nhất không chỉ là các dòng mã nguồn đã viết,
mà là một Nền tảng kiến trúc vững chắc, linh hoạt, giúp doanh nghiệp có thể dễ dàng mở
rộngvàpháttriểnbềnvữngtrongtươnglai.
58

Tài liệu tham khảo
[1] S.Newman.BuildingMicroservices:DesigningFine-GrainedSystems.2nd.Sebastopol,
CA:O’ReillyMedia,2021. ISBN:978-1492034025.
[2] I.Nadareishviliandothers.MicroserviceArchitecture:AligningPrinciples,Practices,
andCulture.Sebastopol,CA:O’ReillyMedia,2016. ISBN:978-1491950357.
[3] S. Brown. The C4 model for visualising software architecture. https://c4model.
com/.Accessed:2026-01-01.2024.
[4] The Kubernetes Authors. Kubernetes Documentation. https://kubernetes.io/
docs/.Accessed:2026-01-01.2024.
[5] Helm Authors. Helm Documentation. https://helm.sh/docs/. Accessed: 2026-
01-01.2026.
[6] Helmfile Authors. Helmfile Documentation. https://helmfile.readthedocs.
io/en/latest/.Accessed:2026-01-01.2025.
[7] OracleCorporation.MySQL8.0ReferenceManual.https://dev.mysql.com/doc/
refman/8.0/en/.Accessed:2026-01-01.2024.
[8] Laravel LLC. Laravel 11.x Documentation. https://laravel.com/docs/11.x.
Accessed:2026-01-01.2024.
[9] Kong Inc. Kong Gateway Documentation. https://docs.konghq.com/gateway/.
Accessed:2026-01-01.2024.
[10] ApacheSoftwareFoundation.ApacheKafkaDocumentation.https://kafka.apache.
org/documentation/.Accessed:2026-01-01.2024.
[11] Redis Ltd. Redis Documentation. https://redis.io/docs/. Accessed: 2026-01-
01.2024.
[12] MinIO Inc. MinIO Object Storage Documentation. https://min.io/docs/minio/
linux/index.html.Accessed:2026-01-01.2024.
[13] Vercel Inc. Next.js Documentation. https://nextjs.org/docs. Accessed: 2026-
01-01.2024.
59

[14] Elasticsearch B.V. Elasticsearch Guide. https://www.elastic.co/guide/en/
elasticsearch/reference/current/index.html.Accessed:2026-01-01.2024.
[15] Elasticsearch B.V. Filebeat Quick Start Guide. https://www.elastic.co/guide/
en/beats/filebeat/current/filebeat-overview.html. Accessed: 2026-01-
01.2024.
[16] E. Evans. Domain-Driven Design: Tackling Complexity in the Heart of Software.
Boston,MA:Addison-WesleyProfessional,2003. ISBN:978-0321125217.
[17] C. Richardson. Microservice Architecture Patterns. https://microservices.io/
patterns/.Accessed:2026-01-01.2024.
[18] LinkedIn Corp. LinkedIn Recruiter Overview. https://business.linkedin.com/
talent-solutions/recruiter.Accessed:2026-01-01.2024.
[19] Indeed Inc. Indeed for Employers. https://www.indeed.com/hire. Accessed:
2026-01-01.2024.
[20] TopCV Vietnam. TopCV - Recruitment Technology. https://tuyendung.topcv.
vn/.Accessed:2026-01-01.2024.
[21] NavigosGroup.VietnamWorksRecruitmentSolutions.https://employer.vietnamworks.
com/.Accessed:2026-01-01.2024.
[22] Greenhouse Software, Inc. Greenhouse Applicant Tracking System. https://www.
greenhouse.io/.Accessed:2026-01-01.2024.
[23] SmartRecruitersInc.SmartRecruitersHiringSuccessPlatform.https://www.smartrecruiters.
com/.Accessed:2026-01-01.2024.
[24] G. Smart and R. Street. Who: The A Method for Hiring. Reference for recruitment
processes.NewYork:BallantineBooks,2008. ISBN:978-0345504197.
[25] M.Fowler.UMLDistilled:ABriefGuidetotheStandardObjectModelingLanguage.
3rd. Tài liệu quy chuẩn về các ký pháp trong biểu đồ UML. Boston, MA: Addison-
WesleyProfessional,2003. ISBN:978-0321193681.
[26] C.Larman.ApplyingUMLandPatterns:AnIntroductiontoObject-OrientedAnalysis
andDesignandIterativeDevelopment.3rd.Tàiliệuthamkhảochínhvềphươngpháp
phântíchUseCase.NewJersey:PrenticeHall,2004. ISBN:978-0131489066.
60
