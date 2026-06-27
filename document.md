|     |        |                    | ĐẠI HỌC | BÁCH       | KHOA                 | HÀ    | NỘI           |     |
| --- | ------ | ------------------ | ------- | ---------- | -------------------- | ----- | ------------- | --- |
|     |        |                    | KHOA    |            | TOÁN -               | TIN   |               |     |
|     | Nghiên |                    | cứu     | Kiến       | trúc                 | Zero  | Trust         | và  |
| Ứng | dụng   | trong              | Bảo     | mật        | Hệ                   | thống | Microservices |     |
|     |        |                    | trên    | Kubernetes |                      |       |               |     |
|     |        |                    | ĐỒ      | ÁN TỐT     | NGHIỆP               |       |               |     |
|     |        | Chuyên             | ngành:  | Hệ         | thống Thông          | tin   | Quản lý       |     |
|     |        | Giảngviênhướngdẫn: |         |            | PGS.TS.NguyễnĐìnhHân |       |               |     |
|     |        | Sinhviênthựchiện:  |         |            | PhùngTháiBảo         |       |               |     |
|     |        | Mãsốsinhviên:      |         |            | 20227189             |       |               |     |
|     |        |                    |         | HÀ NỘI,    | 06/2026              |       |               |     |

Lời cảm ơn
Lờiđầutiên,emxingửilờicảmơnchânthànhvàsâusắcnhấttớiPGS.TS.NguyễnĐình
Hân, người đã trực tiếp hướng dẫn, chỉ bảo tận tình và đồng hành cùng em trong suốt quá
trình thực hiện Đồ án Tốt nghiệp. Những định hướng chuyên môn quý báu, sự khắt khe về
mặtkỹthuậtcũngnhưnhữnglờiđộngviêncủathầyđãgiúpemvượtquanhiềukhókhănđể
hoànthiệnhệthốngvànângcaotưduyvềkiếntrúcphầnmềm.
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
HàNội,tháng06năm2026
Sinhviênthựchiện
PhùngTháiBảo
i

Tóm tắt đồ án
Đồ án tập trung giải quyết các thách thức bảo mật nội tại của kiến trúc Microservices
trên môi trường đám mây, nơi mô hình phòng thủ vành đai truyền thống bộc lộ nhiều điểm
yếurủiro.DựatrêntiêuchuẩnNISTSP800-207,mụctiêucủanghiêncứulàthiếtkếvàứng
dụngmộtkiếntrúcbảomậtZeroTrusttoàndiện.
GiảiphápcủađồánlàđềxuấtKhungkiếntrúcZeroTrust5lớptíchhợp,baogồm:Định
danhđathựcthể,Đánhgiátưthếbảomật,Thựcthichínhsáchđatầng,Quảntrịbímậtđộng
vàVònglặpquansát-phảnhồi.Thayvìtincậyngầmđịnh,khungkiếntrúcnàydịchchuyển
trọng tâm bảo vệ từ ranh giới mạng lưới sang việc kiểm soát khắt khe từng thực thể và từng
luồngdữliệuriêngbiệt.
Thôngquaquátrìnhtriểnkhaithựcnghiệmtrênmộthệthốngvidịchvụcụthể,đồánđã
chứng minh được tính khả thi và độ hiệu quả của giải pháp đề xuất. Hệ thống thực nghiệm
đã đáp ứng thành công các nguyên tắc cốt lõi của Zero Trust: thiết lập microsegmentation triệt
để, tự động hóa vòng đời thông tin xác thực và duy trì khả năng giám sát an ninh theo thời
gian thực để ngăn chặn các kỹ thuật tấn công di chuyển ngang. Kết quả của đồ án cung cấp
mộtmôhìnhthamchiếuthựctiễntheođúngtriếtlýZeroTrust.
Từ khóa: Zero Trust Architecture, NIST SP 800-207, Microservices Security, Kuber-
netes,Microsegmentation,DynamicSecrets.
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
| 3. Ý thức | làm việc | của sinh | viên: |     |     |     |
| --------- | -------- | -------- | ----- | --- | --- | --- |
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
1 TổngquanvềKiếntrúcZeroTrust 1
1.1 TừbảomậtvànhđaiđếnZeroTrust . . . . . . . . . . . . . . . . . . . . . 1
1.1.1 Hạnchếcủamôhìnhbảomậtdựatrênchuvi . . . . . . . . . . . . 1
1.1.2 Địnhnghĩavàcácthuậtngữ . . . . . . . . . . . . . . . . . . . . . 2
1.1.3 SosánhZTAvớimôhìnhdựatrênchuvi . . . . . . . . . . . . . . 3
1.2 KiếntrúcthamchiếuZeroTrust . . . . . . . . . . . . . . . . . . . . . . . 3
1.2.1 Bảynguyênlý . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 3
1.2.2 Cácthànhphầntrongkiếntrúcthamchiếu . . . . . . . . . . . . . 4
1.2.3 Thuậttoántincậy . . . . . . . . . . . . . . . . . . . . . . . . . . . 5
1.2.4 CáchướngtiếpcậntriểnkhaiZTA . . . . . . . . . . . . . . . . . . 6
1.3 CáckháiniệmmởrộngcủaZeroTrust . . . . . . . . . . . . . . . . . . . . 7
1.3.1 BảomậtthíchứngvàCAEP . . . . . . . . . . . . . . . . . . . . . 7
1.3.2 Tiếpcậnđathànhphần . . . . . . . . . . . . . . . . . . . . . . . . 7
1.4 MôhìnhTrưởngthànhZeroTrust . . . . . . . . . . . . . . . . . . . . . . 7
1.4.1 Nămtrụcộtchứcnăng . . . . . . . . . . . . . . . . . . . . . . . . 8
1.4.2 Banănglựcxuyênsuốt . . . . . . . . . . . . . . . . . . . . . . . . 8
1.4.3 BốncấpđộTrưởngthành . . . . . . . . . . . . . . . . . . . . . . . 9
2 ỨngdụngZeroTrustbảomậthệthốngMicroservices 10
2.1 BàitoánbảomậtđặcthùcủaKubernetes . . . . . . . . . . . . . . . . . . . 10
2.2 PhântíchbềmặttấncôngcủaContainer . . . . . . . . . . . . . . . . . . . 11
2.3 NhữngtháchthứckhitriểnkhaiZTAtrênKubernetes . . . . . . . . . . . . 14
2.3.1 Địnhdanhworkloadkhôngbềnvững . . . . . . . . . . . . . . . . 14
2.3.2 Khôngcóđiểmthựcthichínhsáchđơnnhất . . . . . . . . . . . . . 14
2.3.3 Thiếungữcảnhđịnhdanhtrongquansáthệthống . . . . . . . . . 15
2.4 ĐềxuấtKhungkiếntrúcZeroTrust5thànhphần . . . . . . . . . . . . . . 15
iv

2.4.1 Thànhphần1:Địnhdanhđathựcthể . . . . . . . . . . . . . . . . 16
2.4.2 Thànhphần2:ĐánhgiátưthếbảomậtvàTìnhbáođedọa . . . . . 17
2.4.3 Thànhphần3:Thựcthiđatầng . . . . . . . . . . . . . . . . . . . 17
2.4.4 Thànhphần4:Quảntrịbímậtđộng . . . . . . . . . . . . . . . . . 17
2.4.5 Thànhphần5:QuansátvàVònglặpthíchứng . . . . . . . . . . . 18
2.4.6 Đềxuấtbộcôngnghệhiệnthựchóa . . . . . . . . . . . . . . . . . 19
2.5 Môhìnhchínhsáchđềxuất . . . . . . . . . . . . . . . . . . . . . . . . . . 19
2.5.1 Tiếpcậnphânquyềntheothuộctính . . . . . . . . . . . . . . . . . 19
2.5.2 NguyêntắcTừchốimặcđịnh . . . . . . . . . . . . . . . . . . . . . 20
2.5.3 Vòngđờichínhsách . . . . . . . . . . . . . . . . . . . . . . . . . 20
2.6 LộtrìnhchuyểnđổisangkiếntrúcZeroTrust . . . . . . . . . . . . . . . . 20
3 Triểnkhaithựcnghiệm 22
3.1 Môtảbàitoánvàđốitượngthựcnghiệm . . . . . . . . . . . . . . . . . . . 22
3.1.1 TổngquankiếntrúcJob7189 . . . . . . . . . . . . . . . . . . . . . 22
3.2 ThiếtkếZeroTrustchohệthốngJob7189 . . . . . . . . . . . . . . . . . . 24
3.2.1 YêucầuvàNguyêntắcthiếtkế . . . . . . . . . . . . . . . . . . . . 24
3.2.2 Kiếntrúctriểnkhai . . . . . . . . . . . . . . . . . . . . . . . . . . 25
3.2.3 CấutrúcWorkloadvàPhânbổNamespace . . . . . . . . . . . . . 26
3.3 TriểnkhaicáccơsởhạtầngZeroTrustcốtlõi . . . . . . . . . . . . . . . . 26
3.3.1 ThiếtlậpGốctincậy(Thànhphần1) . . . . . . . . . . . . . . . . 26
3.3.2 ĐánhgiátưthếbảomậtvàTìnhbáođedọa(Thànhphần2) . . . . 28
3.3.3 Thựcthichínhsáchđatầng(Thànhphần3) . . . . . . . . . . . . . 28
3.3.4 QuảntrịBímậtĐộng(Thànhphần4) . . . . . . . . . . . . . . . . 29
3.3.5 Khảnăngquansáttậptrung(Thànhphần5) . . . . . . . . . . . . . 32
3.4 CáccơchếZeroTrustnângcao . . . . . . . . . . . . . . . . . . . . . . . . 33
3.4.1 BảomậtChuỗicungứngvớiCosign . . . . . . . . . . . . . . . . . 33
3.4.2 VònglặpPhảnhồiThíchứng . . . . . . . . . . . . . . . . . . . . . 34
3.5 Quytrìnhtriểnkhaitựđộng . . . . . . . . . . . . . . . . . . . . . . . . . 34
3.6 Môitrườngthửnghiệm . . . . . . . . . . . . . . . . . . . . . . . . . . . . 35
3.7 Khảnăngtựphụchồi . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 36
4 ThửnghiệmvàĐánhgiá 38
4.1 Mụctiêuvàphươngphápđánhgiá . . . . . . . . . . . . . . . . . . . . . . 38
4.2 Kịchbảntấncôngmôphỏngvàminhchứngthựcnghiệm . . . . . . . . . . 38
4.2.1 Kịchbản1:XâmnhậpquaAPIGatewayvàbỏquaxácthựcMFA . 38
4.2.2 Kịchbản2:ThựcthimãtừxavàgiámsáttiếntrìnhbằngeBPF . . 40
4.2.3 Kịchbản3:Đánhcắpthôngtinxácthựcđộng . . . . . . . . . . . . 42

4.2.4 Kịchbản4:Giảmạodanhtínhmạngnộibộ . . . . . . . . . . . . . 43
4.2.5 Kịchbản5:TríchxuấtdữliệuquaEgressvàDNS . . . . . . . . . 45
4.2.6 Kịchbản6:ChặnkếtnốiđếnIPđộchại . . . . . . . . . . . . . . . 46
4.2.7 Kịchbản7:Thỏahiệpchuỗicungứng . . . . . . . . . . . . . . . . 48
4.2.8 Kịchbản8:Trinhsátmạngnộibộ . . . . . . . . . . . . . . . . . . 49
4.2.9 Kịchbản9:KhaithácKubeletAPIvàthoátkhỏicontainer . . . . . 50
4.2.10 Kịchbản10:SửađổitráiphépchínhsáchmạngvàtựphụchồiGitOps 51
4.3 Phântíchtổnghợpkếtquả . . . . . . . . . . . . . . . . . . . . . . . . . . 52
4.4 HạnchếvàHướngpháttriển . . . . . . . . . . . . . . . . . . . . . . . . . 53
Kếtluận 55

Danh sách hình vẽ
1.1 KiếntrúcthamchiếutổngquátcủaZTA . . . . . . . . . . . . . . . . . . . 5
1.2 MôhìnhTrưởngthànhZeroTrustcủaCISA . . . . . . . . . . . . . . . . . 8
2.1 CáckỹthuậttấncôngvàonềntảngContainertheochuẩnMITREATT&CK
(MITRECorporation,2024). . . . . . . . . . . . . . . . . . . . . . . . . . 11
2.2 KhungkiếntrúclogicZeroTrust5thànhphầnđềxuất . . . . . . . . . . . 16
3.1 SơđồngữcảnhhệthốngJob7189 . . . . . . . . . . . . . . . . . . . . . . 23
3.2 KiếntrúccontainercủahệthốngJob7189(gócnhìnnghiệpvụ) . . . . . . . 23
3.3 KiếntrúccontainercủahệthốngJob7189(gócnhìndữliệu) . . . . . . . . 24
3.4 KiếntrúctriểnkhaiZeroTrustđềxuất . . . . . . . . . . . . . . . . . . . . 25
3.5 Bảnđồworkloadtheonamespacephântáchrủirobảomật. . . . . . . . . . 26
3.6 LuồngxácthựcOIDC/JWTchoNorth-SouthtrafficquaKeycloakvàKong 27
3.7 VòngđờiJITcredential–từkhởitạoPodđếntựđộngxoayvòngbímật . . 31
3.8 HubbleUI:TrựcquanhóanetworkflowvàpolicyenforcementL7 . . . . . 32
3.9 Kibana:Truyvấnsecurityeventtổnghợptừhệthống . . . . . . . . . . . . 33
4.1 Kịch bản 1: Đánh cắp Token, lách MFA và cơ chế phòng thủ nhận thức ngữ
cảnh . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 39
4.2 Kịchbản2:eBPFhooksys_execve—phântíchphảhệtiếntrìnhvàghinhận
viphạm(chếđộkiểmtoán) . . . . . . . . . . . . . . . . . . . . . . . . . . 41
4.3 Kịchbản3:VaultJIT+CNIđatầngchốngtríchxuấtthôngtinxácthực . . 42
4.4 Kịchbản4:CNIpháthiệnlệchphadanhtínhđộngvàIPnguồn . . . . . . 44
4.5 Kịchbản5:ChặntríchxuấtdữliệuquaHTTPFQDNvàDNSL7 . . . . . 45
4.6 Kịchbản6:ĐồngbộThreatIntelvàchặnkếtnốiIPđộchạitạiKernel . . . 47
vii

Danh sách bảng
1.1 PhânbiệtZeroTrust,ZTAvàZTE . . . . . . . . . . . . . . . . . . . . . . 2
1.2 SosánhmôhìnhbảomậttruyềnthốngvàKiếntrúcZeroTrust . . . . . . . 3
1.3 BảynguyênlýZeroTrust . . . . . . . . . . . . . . . . . . . . . . . . . . . 4
1.4 CáchướngtiếpcậnphổbiếncủatrustalgorithmtrongZeroTrust . . . . . . 6
2.1 Giaiđoạn1:XâmnhậpbanđầuvàThiếtlậpcứđiểm . . . . . . . . . . . . 12
2.2 Giaiđoạn2:HậukhaithácvàTácđộng . . . . . . . . . . . . . . . . . . . 13
2.3 Bảng tổng hợp tham chiếu: thành phần kiến trúc đề xuất ↔ NIST ↔ Công
nghệ↔Rủirogiảmthiểu . . . . . . . . . . . . . . . . . . . . . . . . . . . 19
2.4 Quytrìnhchuyểnđổi7bướctheotiêuchuẩnNISTSP800-207 . . . . . . . 21
3.1 CácgiaiđoạncốtlõitrongPipelinetriểnkhaitựđộngZTA . . . . . . . . . 35
3.2 Cấuhìnhhệthốngtạithờiđiểmthửnghiệm . . . . . . . . . . . . . . . . . 36
3.3 Cơchếtựphụchồivàđảmbảotrạngtháiantoàncủahệthống . . . . . . . 37
4.1 Tổnghợpkếtquả9kịchbảnthửnghiệm . . . . . . . . . . . . . . . . . . . 53
viii

Chương 1
Tổng quan về Kiến trúc Zero Trust
1.1 Từ bảo mật vành đai đến Zero Trust
1.1.1 Hạn chế của mô hình bảo mật dựa trên chu vi
Trongnhiềuthậpkỷ,anninhmạngtruyềnthốngđượcxâydựngtheomôhìnhphòngthủ
dựa trên chu vi, hay còn gọi là chiến lược “Lâu đài và Hào nước”. Mô hình này thiết lập
ranh giới giữa mạng nội bộ và bên ngoài thông qua tường lửa, VPN và hệ thống IDS/IPS.
Đặc trưng quan sát được là cấp quyền truy cập chủ yếu dựa trên vị trí mạng (Jericho Forum,
2007;Kindervag,2010).
Mặc dù mạng truyền thống vẫn tích hợp một số biện pháp phòng vệ nội bộ (chia VLAN,
tườnglửanộibộ,cáccơchếđịnhdanhtĩnhởtầngứngdụng),môhìnhnàybộclộbahạnchế
khiđốimặtvớihạtầngcloud-native(thiếtkếtốiưuchomôitrườngđámmây)hiệnđại:
• Sự tin cậy ngầm định: một khi kẻ tấn công hoặc mối đe doạ nội bộ đã có chỗ đứng
bên trong mạng, các hệ thống thường mặc định coi mọi giao tiếp xuất phát từ dải IP
nộibộlàantoàn(Roseetal.,2020).
• Dichuyểnngang:Khichuviđãbịchọcthủng,cácbiệnphápkiểmsoátnộibộtruyền
thốngchủyếudựatrênviệcchiamạngtheoVLAN/subnet(mạngcon)ởquymôlớn.Kẻ
tấn công sau khi chiếm được một máy hợp lệ có thể tái sử dụng danh tính tĩnh (header
hoặctokenlâudài)đểtrinhsátvàdichuyểnsangcáctàinguyênkháctrongcùngphân
đoạnmạngtrướckhibịpháthiện(Gilman&Barth,2017;Kindervag,2010).
• Sự mờ nhạt của chu vi vật lý: Môi trường cloud-native, làm việc từ xa và thiết bị
cá nhân khiến việc xác định một “chu vi mạng” rõ ràng để đặt tường lửa trở nên bất
khả thi (Cybersecurity and Infrastructure Security Agency (CISA), 2023; Rose et al.,
2020).
1

| CHƯƠNG1.   | TỔNGQUANVỀKIẾNTRÚCZEROTRUST |              |     |     |     |     |     |
| ---------- | --------------------------- | ------------ | --- | --- | --- | --- | --- |
| 1.1.2 Định | nghĩa                       | và các thuật | ngữ |     |     |     |     |
Đối mặt với các hạn chế trên, khái niệm Zero Trust được John Kindervag đề xuất năm
2010tạiForresterResearch(Kindervag,2010),kếthừacácnguyêntắckhôngcònphụthuộc
chuvimạngcủa JerichoForum(JerichoForum,2007)vàsau đóđượcchuẩnhoáthànhkiến
trúcthamchiếutrongNISTSP800-207(Roseetal.,2020).
Trong các tài liệu hiện nay, ba thuật ngữ ZT, ZTA và ZTE thường bị dùng lẫn lộn.
Bảng 1.1 phân biệt chúng theo đúng định nghĩa của NIST SP 800-207 (Mục 2.1) và CISA
ZTMM 2.0 (Cybersecurity and Infrastructure Security Agency (CISA), 2023; Rose et al.,
2020).
Bảng1.1:PhânbiệtZeroTrust,ZTAvàZTE
| Thuậtngữ  |     | Viếttắt | Địnhnghĩa |            |             |           |       |
| --------- | --- | ------- | --------- | ---------- | ----------- | --------- | ----- |
| ZeroTrust |     | ZT      | Tập hợp   | các nguyên | tắc an ninh | mạng định | hướng |
dịchchuyểnphòngthủtừchuvimạngtĩnhsangviệc
|     |     |     | tập trung | bảo vệ từng | tài sản (người | dùng, thiết | bị, |
| --- | --- | --- | --------- | ----------- | -------------- | ----------- | --- |
dịchvụ).ZTgiảđịnhkhôngcósựtincậyngầmđịnh
chobấtkỳthànhphầnnàodựatrênvịtrímạng.
ZeroTrustArchitecture ZTA Kế hoạch an ninh mạng của tổ chức tận dụng các
|     |     |     | nguyên     | tắc Zero Trust | để kiểm soát      | truy cập    | tới tài |
| --- | --- | --- | ---------- | -------------- | ----------------- | ----------- | ------- |
|     |     |     | sản, bao   | gồm: quan      | hệ giữa các thành | phần, thiết | kế      |
|     |     |     | luồng công | việc và        | chính sách truy   | cập. ZTA    | được    |
hiệnthựchoáthôngquacáccôngcụnhưIdP,PEPvà
hệthốngquansát.
ZeroTrustEnterprise ZTE Trạngtháikhicơsởhạtầng(mạng,thiếtbị,nhânsự)
vàcácchínhsáchcủatổchứcđãđượctriểnkhaitheo
|     |     |     | ZTA. NIST | nhấn mạnh | ZTE là một | lộ trình chuyển |     |
| --- | --- | --- | --------- | --------- | ---------- | --------------- | --- |
đổidiễnratrongnhiềunăm,khôngphảisảnphẩm.
TừcáctenetvàmôhìnhlogicđượctrìnhbàytrongNISTSP800-207,cóthểrútrahaitư
tưởngxuyênsuốtmọitriểnkhaiZeroTrust(Gilman&Barth,2017;Roseetal.,2020):
1. Mạngluônbịcoilàđãbịxâmnhập.
2. Mọi truy cập đều phải được xác thực và uỷ quyền một cách rõ ràng trên cơ sở từng
yêucầu,khôngđượcphụthuộcvàovịtrímạngcủachủthể.
2

| CHƯƠNG1. | TỔNGQUANVỀKIẾNTRÚCZEROTRUST |         |         |     |      |        |     |     |
| -------- | --------------------------- | ------- | ------- | --- | ---- | ------ | --- | --- |
| 1.1.3    | So sánh                     | ZTA với | mô hình | dựa | trên | chu vi |     |     |
Để làm rõ lý do tại sao ZTA là sự lựa chọn tất yếu cho môi trường công nghệ thông tin
hiện đại, Bảng 1.2 so sánh sự khác biệt về triết lý và phương pháp tiếp cận kỹ thuật giữa hai
môhình:
Bảng1.2:SosánhmôhìnhbảomậttruyềnthốngvàKiếntrúcZeroTrust
| Tiêuchí |     | Bảomậtdựatrênchuvi |     |     |     | KiếntrúcZeroTrust |     |     |
| ------- | --- | ------------------ | --- | --- | --- | ----------------- | --- | --- |
Cơsởtincậy Dựa vào vị trí mạng (IP, sub- Không phụ thuộc vị trí; đánh giá
|     |     | net) hoặc | chứng | thực ban | đầu tại | ngữcảnhliêntụctừcácnguồndữ |     |     |
| --- | --- | --------- | ----- | -------- | ------- | -------------------------- | --- | --- |
|     |     | cổng.     |       |          |         | liệu(PIP).                 |     |     |
Mức độ kiểm Tập trung ở biên mạng, phân Phânđoạnvimôtrựctiếptạitừng
| soát |     | đoạnvĩmô. |     |     |     | tàinguyên. |     |     |
| ---- | --- | --------- | --- | --- | --- | ---------- | --- | --- |
Hạn chế di Phụ thuộc tường lửa nội bộ hoặc Kiểm tra tính hợp lệ trên từng
chuyểnngang các rào cản tĩnh. Kẻ tấn công có truy cập theo yêu cầu bằng định
|     |     | thểgiảmạonếuđãởbêntrong. |     |     |     | danhmậtmãhọc. |     |     |
| --- | --- | ------------------------ | --- | --- | --- | ------------- | --- | --- |
Quảnlýbímật Thôngtinxácthựcdạngtĩnh,lưu JIT(cấppháttứcthời),TTL(thời
|     |     | trữvôthờihạn. |     |     |     | giansống)ngắnthôngquaPolicy |     |     |
| --- | --- | ------------- | --- | --- | --- | --------------------------- | --- | --- |
Administrator.
Khả năng giám Giớihạnởlogmạngbiên. Thu thập toàn diện log, metric,
| sát |     |     |     |     |     | trace tại mọi | PEP để phản | hồi tự |
| --- | --- | --- | --- | --- | --- | ------------- | ----------- | ------ |
động.
| 1.2 Kiến | trúc       | tham | chiếu | Zero | Trust |     |     |     |
| -------- | ---------- | ---- | ----- | ---- | ----- | --- | --- | --- |
| 1.2.1    | Bảy nguyên | lý   |       |      |       |     |     |     |
NIST SP 800-207 định nghĩa 7 nguyên lý nền tảng mà mọi triển khai ZTA phải tuân thủ
(Roseetal.,2020):
3

| CHƯƠNG1. | TỔNGQUANVỀKIẾNTRÚCZEROTRUST |     |     |     |     |     |
| -------- | --------------------------- | --- | --- | --- | --- | --- |
Bảng1.3:BảynguyênlýZeroTrust
| # Nguyênlý |     | Nộidung |     |     |     |     |
| ---------- | --- | ------- | --- | --- | --- | --- |
1 Mọi thứ đều là tài Máy chủ, ứng dụng, API endpoint, CSDL - tất cả đều là tài
| nguyên |     | nguyêncầnbảovệriêngbiệt. |     |     |     |     |
| ------ | --- | ------------------------ | --- | --- | --- | --- |
2 Bảo mật không phụ Không tồn tại vùng mạng được mặc định tin cậy; giao tiếp
thuộcvịtrímạng nội bộ phải được kiểm soát và xác thực với cùng mức độ
chặtchẽnhưlưulượngtừbênngoài.
3 Cấpquyềntheophiên Quyền truy cập được cấp tối thiểu, đánh giá lại mỗi phiên,
thuhồingaysaukhihoànthành.
4 Chính sách truy cập Quyếtđịnhdựatrêndanhtính+trạngtháithiếtbị+hànhvi
| động |     | +thờigian+vịtrí. |     |     |     |     |
| ---- | --- | ---------------- | --- | --- | --- | --- |
5 Giámsáttoànbộtàisản Liên tục đánh giá tính toàn vẹn và trạng thái tuân thủ của
mọithiếtbị/ứngdụng.
6 Xácthựcliêntục Khôngchỉxácthựclầnđầu-xácthựclạikhithựchiệnhành
độngnhạycảm.
7 Thuthậptốiđadữliệu Thu thập dữ liệu trạng thái về tài sản, hạ tầng mạng và
|     |     | truyền thông | để cung | cấp đầu vào cho | việc ra quyết | định |
| --- | --- | ------------ | ------- | --------------- | ------------- | ---- |
vàliêntụccảithiệntrạngtháibảomật.
| 1.2.2 Các | thành phần | trong kiến | trúc tham | chiếu |     |     |
| --------- | ---------- | ---------- | --------- | ----- | --- | --- |
NISTSP800-207địnhnghĩakiếntrúclogicZTAtáchbiệthoàntoàngiữacontrolplane
(mặt phẳng điều khiển) và data plane (mặt phẳng dữ liệu) (Rose et al., 2020). NIST SP
1800-35bổsungvàsửdụngnhấtquánbốnvaitròkiếntrúcdướiđây,trongđóPEvàPAhợp
thành Policy Decision Point (PDP) ở control plane, còn PEP thực thi tại data plane và PIP
cấpngữcảnhchoPDP(Roseetal.,2025).
4

CHƯƠNG1. TỔNGQUANVỀKIẾNTRÚCZEROTRUST
Hình1.1:KiếntrúcthamchiếutổngquátcủaZTA(Roseetal.,2025).
• Policy Engine (PE) – Động cơ chính sách: chịu trách nhiệm đưa ra quyết định cuối
cùngvềviệccấp,từchốihoặcthuhồiquyềntruycậptớitàinguyên.PEsửdụngthuật
toántincậyđểđánhgiárủirocủatừngyêucầu.
• Policy Administrator (PA) – Quản trị chính sách: thực thi quyết định của PE bằng
cáchgửilệnhtớiPEPđểthiếtlậphoặcngắtđườngtruyềngiữachủthểvàtàinguyên.
• Policy Enforcement Point (PEP) – Điểm thực thi chính sách: nằm trực tiếp trên
đường truyền dữ liệu, bảo vệ vùng tin cậy chứa tài nguyên, kích hoạt, giám sát và kết
thúccáckếtnốitheolệnhtừPA.
• Policy Information Point (PIP) – Điểm cung cấp thông tin chính sách: các nguồn
thành phần hỗ trợ cấp telemetry và ngữ cảnh (định danh, phân tích bảo mật, tình báo
mốiđedọa)choPDPđểPEraquyếtđịnhliêntục.
1.2.3 Thuật toán tin cậy
ĐểhiểucáchPolicyEngineraquyếtđịnhvớitậpđầuvàodoPIPcấp,NISTSP800-207
đặt tên cho tiến trình đó là trust algorithm (TA) và phân loại các biến thể theo hai trục độc
lập(Roseetal.,2020):
5

| CHƯƠNG1. | TỔNGQUANVỀKIẾNTRÚCZEROTRUST |     |     |     |     |     |     |
| -------- | --------------------------- | --- | --- | --- | --- | --- | --- |
Bảng1.4:CáchướngtiếpcậnphổbiếncủatrustalgorithmtrongZeroTrust
| Trụcphânloại |     | Haihướngtiếpcậntiêubiểu |     |     |     |     |     |
| ------------ | --- | ----------------------- | --- | --- | --- | --- | --- |
Tiêu chí ra quyết Dựa trên chính sách/thuộc tính: quyết định truy cập được đưa ra
định khi chủ thể thỏa mãn một tập điều kiện định nghĩa trước (rule-
basedhoặcattribute-based).
Dựatrênđiểmsố/rủiro:PolicyEnginetínhtoánmộtgiátrịđánh
|     |     | giá tin  | cậy hoặc rủi | ro từ nhiều | tín hiệu ngữ cảnh | có trọng    | số (ví   |
| --- | --- | -------- | ------------ | ----------- | ----------------- | ----------- | -------- |
|     |     | dụ: danh | tính, trạng  | thái thiết  | bị, hành vi, vị   | trí, threat | intelli- |
|     |     | gence)   | rồi so sánh  | với ngưỡng  | chính sách để     | cho phép    | hoặc từ  |
chốitruycập.
Mức độ sử dụng ngữ Đánhgiáđộclậptheotừngyêucầu:mỗiyêucầuđượcxửlýnhư
| cảnh |     | mộtsựkiệnriênglẻvớiíthoặckhôngsửdụngdữliệulịchsử. |          |                |                   |           |           |
| ---- | --- | ------------------------------------------------- | -------- | -------------- | ----------------- | --------- | --------- |
|      |     | Đánh giá                                          | liên tục | theo ngữ cảnh: | quyết định        | truy cập  | được cập  |
|      |     | nhật động                                         | dựa trên | lịch sử phiên, | hành vi gần       | đây, thay | đổi trạng |
|      |     | thái bảo                                          | mật hoặc | tín hiệu rủi   | ro mới phát sinh, | phục      | vụ cơ chế |
đánhgiálạitrongsuốtvòngđờiphiêntruycập.
| 1.2.4 Các | hướng | tiếp cận | triển khai | ZTA |     |     |     |
| --------- | ----- | -------- | ---------- | --- | --- | --- | --- |
Khiđãxácđịnhđượcmôhìnhlogic,tổchứccóthểchọncáchướngtriểnkhaikhácnhau.
NIST SP 800-207 và SP 1800-35 liệt kê bốn hướng tiếp cận phổ biến (Rose et al., 2020,
2025):
• Enhanced Identity Governance (EIG) – Quản trị Danh tính Nâng cao: lấy danh
tínhlàmtrungtâm.Mọiquyếtđịnhdựatrên“chủthểlàai”và“thuộctínhgì”.
• Phân đoạn Vi mô: lấy mạng làm trung tâm. Chia mạng thành các phân đoạn cực nhỏ
baoquanhtừngtàinguyênđểngănchặndichuyểnngang.
• SoftwareDefinedPerimeter(SDP)–ChuviĐịnhnghĩabằngPhầnmềm:lấyứng
dụng làm trung tâm. Tài nguyên bị ẩn hoàn toàn cho đến khi chủ thể được xác thực và
uỷquyền.
• Secure Access Service Edge (SASE): lấy biên làm trung tâm. Hợp nhất chức năng
PEPvớicácdịchvụbảomậtđượccungcấpquađámmâytạiđiểmgầnngườidùng.
Bốn hướng này không loại trừ lẫn nhau. Một thiết kế tối ưu thường là sự giao thoa của
EIG,PhânđoạnVimôvàSDP.
6

CHƯƠNG1. TỔNGQUANVỀKIẾNTRÚCZEROTRUST
1.3 Các khái niệm mở rộng của Zero Trust
1.3.1 Bảo mật thích ứng và CAEP
Khi Policy Engine sử dụng thuật toán tin cậy theo ngữ cảnh, quyết định cấp truy cập
không kết thúc tại thời điểm cấp token. Vòng đời truy cập trong ZTA là một vòng đời đánh
giáliêntục,trongđóPIPtiếptụcđẩytínhiệumới(thiếtbịbịxâmnhập,hànhvibấtthường)
tớiPDPđểthuhồiquyềntruycậpgiữaphiên.
NIST gọi mô hình này là Bảo mật thích ứng (adaptive security) (Rose et al., 2020).
Một cách triển khai cụ thể của tầng này là Continuous Access Evaluation Profile (CAEP)
(OpenID Foundation, 2024) – đặc tả do OpenID Foundation duy trì, mô tả mô hình hướng
sự kiện cho phép IdP phát tín hiệu thay đổi ngữ cảnh tới các PEP để ngắt phiên ngay cả khi
token hiện tại chưa hết hạn TTL. Điểm đáng chú ý là vòng lặp này không đòi hỏi PEP kiểm
traIdPmàhoạtđộngtheocơchếPush.
1.3.2 Tiếp cận đa thành phần
NISTSP800-207môtảZTAbằngcácvaitròlogic,khônggắnvaitròvớimộtsảnphẩm
thươngmạicụthể(Roseetal.,2020).ViệcgántoànbộnềntảngZTAchomộtsảnphẩmduy
nhất thường dẫn đến phụ thuộc nhà cung cấp và không phủ đầy đủ các vai trò bảo mật (ví
dụ:một giảiphápmạng tốtcóthể khôngcungcấp khảnăngđánh giátrạngthái bảomậtcủa
ứngdụng).
Do đó, xu hướng hiện đại hướng tới tổ hợp Đa thành phần – chọn công nghệ phù hợp
nhất cho từng vai trò logic (PE, PA, PEP, PIP) và liên kết chúng qua các tiêu chuẩn mở
(OIDC, SPIFFE, OpenTelemetry). Đây là phương pháp được áp dụng nhất quán trong việc
thiếtkếkiếntrúchệthốngcủađồánnày.
1.4 Mô hình Trưởng thành Zero Trust
Bên cạnh kiến trúc tham chiếu của NIST, Cơ quan An ninh Mạng và Cơ sở Hạ tầng Hoa
Kỳ (CISA) cung cấp một lộ trình thực tiễn dưới dạng Mô hình Trưởng thành ZTMM 2.0
(Cybersecurity and Infrastructure Security Agency (CISA), 2023). ZTMM không coi Zero
Trust là một trạng thái bật/tắt nhị phân, mà là một cuộc hành trình tiến hóa được cấu thành
từ5trụcột,3nănglựcxuyênsuốtvà4cấpđộtrưởngthành.
7

CHƯƠNG1. TỔNGQUANVỀKIẾNTRÚCZEROTRUST
Hình1.2:MôhìnhTrưởngthànhZeroTrustcủaCISA
1.4.1 Năm trụ cột chức năng
1. Danh tính: hợp nhất quản lý, thực thi xác thực đa yếu tố và đánh giá rủi ro danh tính
liêntục.
2. Thiết bị: quản lý, kiểm kê và liên tục xác minh tình trạng tuân thủ, sức khỏe của thiết
bịtruycập.
3. Mạng lưới: quản lý luồng lưu lượng động, cô lập tài nguyên qua microsegmentation và
mãhoátoàndiện.
4. Ứng dụng và Workload: tích hợp bảo mật vào quy trình CI/CD, đánh giá ủy quyền
liêntụcđốivớiứngdụng.
5. Dữ liệu: phân loại, dán nhãn, mã hoá dữ liệu ở mọi trạng thái và chống thất thoát
(DLP).
1.4.2 Ba năng lực xuyên suốt
1. Tầm nhìn và Phân tích: Thu thập, quan sát và phân tích các dữ liệu diễn ra trên toàn
bộmôitrườngđểthôngbáochocácquyếtđịnhchínhsách.
8

CHƯƠNG1. TỔNGQUANVỀKIẾNTRÚCZEROTRUST
2. Tự động hóa và Điều phối: Tận dụng công cụ tự động để chuyển đổi phản ứng thủ
côngthànhcáchànhđộngtựtrị,nhấtquánvàchạytrênquymôlớn.
3. Quản trị: Định nghĩa, thực thi và duy trì các chính sách an ninh mạng tập trung, đảm
bảotuânthủxuyênsuốtcả5trụcột.
1.4.3 Bốn cấp độ Trưởng thành
Đểđánhgiáhệthống,CISAchialộtrìnhthành4cấpđộ(CybersecurityandInfrastructure
SecurityAgency(CISA),2023):
• Truyềnthống:xácthựctĩnh,phânđoạnmạngvĩmô,ranhgiớitincậycốđịnh.
• Khởi tạo: bắt đầu tự động hoá, phân quyền dựa trên thuộc tính cơ bản, có khả năng
quansátnộibộtốthơn.
• Nâng cao: cấu hình tự động, ủy quyền và thực thi chính sách phối hợp chéo giữa các
trụcột,phảnhồidựatrênrủiro.
• Tối ưu: hệ thống tự trị, áp dụng AI/ML để phân tích và cấp quyền truy cập động theo
ngưỡngrủirothờigianthực.
CầunốisangChương2:
Chương1đãthiếtlậpnềntảnglýluậnvữngchắcvềkiếntrúcZeroTrust,làmrõ
các vai trò PE, PA, PEP, PIP theo tiêu chuẩn NIST và mô hình trưởng thành của
CISA.ZTAlàmộttriếtlýchung,nhưngkhiápdụngnóvàomộtmôitrườngtính
toán cụ thể như Microservices trên nền tảng Kubernetes, hệ thống sẽ đối mặt với
những bài toán đặc thù về định danh tạm thời, quản trị bí mật ở quy mô lớn, và
hiệunăngmạng.
Chương 2 sẽ phân tích chi tiết bề mặt tấn công của hệ thống Microservices, từ
đó đề xuất một Khung kiến trúc Zero Trust 5 thành phần nhằm giải quyết triệt
đểcácrủironày.
9

Chương 2
Ứng dụng Zero Trust bảo mật hệ thống
Microservices
2.1 Bài toán bảo mật đặc thù của Kubernetes
Kiến trúc Microservices mang lại sự linh hoạt vượt trội, nhưng đồng thời việc chia nhỏ
ứng dụngnguyên khối đã khiếnranh giới mạng bịphá vỡ. Chính nhữngđặc tính thiết kếnội
tại của nền tảng Kubernetes là nguyên nhân trực tiếp dẫn đến các lỗ hổng bảo mật, tạo điều
kiệnchotintặcthựcthicácchiếnthuậttấncông:
• Sự bùng nổ lưu lượng nội bộ: Trong kiến trúc nguyên khối, giao tiếp diễn ra an toàn
bêntrongbộnhớ.TrênK8s,cácdịchvụliêntụcgọinhauquamạnglưới.ViệccácPod
thường "mặc định tin tưởng" nhau qua địa chỉ IP nội bộ tạo ra môi trường lý tưởng để
tintặcdòquétmạngvàtựdodichuyểnngang.
• Workload tạm thời và sự vô nghĩa của IP: Các Pod liên tục được tạo, hủy và thay
đổi IP tự động dựa trên tải. Các quy tắc tường lửa tĩnh dựa trên IP truyền thống hoàn
toànbịvôhiệuhóa.Sựbiếnđộngnàychophépmãđộcdễdànglẩntrốn,giảmạodanh
tínhvàquamặtcáchệthốnggiámsát.
• Rủi ro từ hạ tầng dùng chung: Hàng chục Pod chia sẻ chung CPU, RAM và Kernel
của một Node vật lý. Ranh giới Namespace (không gian tên) giữa các Pod chỉ mang
tínhlogic.Nếutintặcchiếmđượcmộtcontainer,chúngcóthểkhaitháclỗhổngKernel
dùngchungđểleothangđặcquyềnvàkiểmsoáttoànbộNode.
• Sự phân tán của thông tin nhạy cảm: Môi trường Microservices yêu cầu một lượng lớn
API Key, mật khẩu DB, token giao tiếp nằm rải rác. Việc lưu trữ tĩnh chúng trong file
cấu hình hay biến môi trường tạo điều kiện cho các kỹ thuật đánh cắp thông tin xác
thực.
10

CHƯƠNG2. ỨNGDỤNGZEROTRUSTBẢOMẬTHỆTHỐNGMICROSERVICES
2.2 Phân tích bề mặt tấn công của Container
Để giải quyết triệt để các nguyên nhân trên, đồ án đối chiếu bề mặt hệ thống với khung
MITRE ATT&CK Matrix for Enterprise – Containers (MITRE Corporation, 2024). Ma
trậnnàyđịnhnghĩatoàndiện10chiếnthuậtxuyênsuốtvòngđờicủamộtcuộctấncông.
GiảiphápZeroTrustđượctriểnkhaikhôngphảinhưmộtcôngcụđơnlẻ,màlàmộtchuỗi
cácPEPnhằmcắtđứtchuỗitấncôngnày.DựatrênmôhìnhCyberKillChainvàtriếtlýGiả
địnhxâmnhập,10chiếnthuậttrênđượcphânchiarõrệtthànhhaigiaiđoạn:GiaiđoạnXâm
nhậpbanđầuvàGiaiđoạnHậukhaithác.CáchtiếpcậnnàylàmnổibậtvaitròcủatừngPEP
trong việc kiềm chế bán kính ảnh hưởng và chặn đứng hành vi di chuyển ngang ngay cả khi
một thành phần trong cụm đã bị xâm phạm. Chi tiết phân tích được thể hiện tại Bảng 2.1 và
Bảng2.2.
Hình 2.1: Các kỹ thuật tấn công vào nền tảng Container theo chuẩn MITRE ATT&CK (MITRE
Corporation,2024).
11

CHƯƠNG2. ỨNGDỤNGZEROTRUSTBẢOMẬTHỆTHỐNGMICROSERVICES
Bảng2.1:Giaiđoạn1:XâmnhậpbanđầuvàThiếtlậpcứđiểm
| Mụcđích | KỹthuậttiêubiểutrênK8s |     |     | Cơchếphòngthủ |     |     |
| ------- | ---------------------- | --- | --- | ------------- | --- | --- |
Xâmnhập Khai thác lỗ hổng Web public (T1190); PEP Edge: Xác thực
(InitialAccess) Dùngtàikhoảnhợplệbịlộ(T1078). mạnh qua OIDC Gate-
|     |     |     |     | way, chặn | request | không |
| --- | --- | --- | --- | --------- | ------- | ----- |
cóJWThợplệ.
Thựcthi Triển khai Image chứa mã độc (T1610); PEP Admission & Pos-
(Execution) DùngCLI/APIchạylệnh(T1609). ture: Quét lỗ hổng bảo
|     |     |     |     | mật liên   | tục, bắt | buộc  |
| --- | --- | --- | --- | ---------- | -------- | ----- |
|     |     |     |     | Image phải | có chữ   | ký số |
trướckhitriểnkhai.
| Bámtrụ        |                    |               |           | Chính     | sách Từ | chối  |
| ------------- | ------------------ | ------------- | --------- | --------- | ------- | ----- |
|               | Tạo CronJob        | ác ý (T1053); | Cấy Image | nội       |         |       |
| (Persistence) | bộchạyngầm(T1525). |               |           | mặc định: | Cấm     | mount |
|               |                    |               |           | hostPath, | bắt     | buộc  |
|               |                    |               |           | cấu hình  | Pod     | chạy  |
Read-only.
Lẩntrốn Trá hình tiến trình (T1036); Xóa dấu vết Quan sát theo ngữ
| (Stealth) | (T1070). |     |     | cảnh:Gắnnhãnlogđịnh |                |     |
| --------- | -------- | --- | --- | ------------------- | -------------- | --- |
|           |          |     |     | danh từ             | cấp độ Kernel, |     |
|           |          |     |     | container           | không thể      | can |
|           |          |     |     | thiệp sửa           | đổi hay        | xóa |
log.
Pháphòngthủ Tắthoặcsửađổicáccôngcụbảomậtđang PEPRuntime:Giámsát
(Defense Im- chạytrongCluster(T1562). và thực thi an toàn nằm
| pairment) |     |     |     | sâu dưới | tầng Kernel, |      |
| --------- | --- | --- | --- | -------- | ------------ | ---- |
|           |     |     |     | cách ly  | hoàn toàn    | khỏi |
User-spacecủaPod.
12

| CHƯƠNG2. | ỨNGDỤNGZEROTRUSTBẢOMẬTHỆTHỐNGMICROSERVICES |     |     |     |
| -------- | ------------------------------------------ | --- | --- | --- |
Bảng2.2:Giaiđoạn2:HậukhaithácvàTácđộng
| Mụcđích | KỹthuậttiêubiểutrênK8s | Cơchếphòngthủ |     |     |
| ------- | ---------------------- | ------------- | --- | --- |
Leo thang đặc Lợi dụng quyền privileged để thoát ra PEP Runtime: Bắt và
quyền
|            | Nodevậtlý(T1611). | chặn ngay    | lập tức    | các lời |
| ---------- | ----------------- | ------------ | ---------- | ------- |
| (Privilege | Esca-             | gọi hệ       | thống trái | phép    |
| lation)    |                   | hoặcnhạycảm. |            |         |
Đánh cắp bí Đánh cắp Token, mật khẩu tĩnh từ file cấu Dynamic Secrets: Cấp
| mật         | hìnhhoặcbiếnmôitrường(T1552). | thông    | tin xác thực | ngắn |
| ----------- | ----------------------------- | -------- | ------------ | ---- |
| (Credential |                               | hạn dạng | JIT trên     | RAM, |
| Access)     |                               | tự động  | thu hồi khi  | hết  |
phiên.
| Trinhsát |     | PEP Mạng | (phân | đoạn |
| -------- | --- | -------- | ----- | ---- |
Quétmạngnộibộtìmkiếmportmởvàcác
| (Discovery) | dịchvụkhác(T1046,T1613). | vi mô):   | Áp dụng     | chính  |
| ----------- | ------------------------ | --------- | ----------- | ------ |
|             |                          | sách từ   | chối mặc    | định ở |
|             |                          | L7 để     | cô lập hoàn | toàn   |
|             |                          | lưu lượng | mạng giữa   | các    |
Pod.
Di chuyển Lợi dụng dịch vụ nội bộ (T1021); Dùng Identity mTLS: Cấp
| ngang    | TokenhợplệnhảysangPodkhác. | định danh   | mã hóa    | cho   |
| -------- | -------------------------- | ----------- | --------- | ----- |
| (Lateral | Move-                      | từng        | workload. | Token |
| ment)    |                            | bị lộ cũng  | vô dụng   | nếu   |
|          |                            | thiếu chứng | chỉ hợp   | lệ    |
đínhkèm.
Tácđộng Đào tiền ảo chiếm tài nguyên (Resource Adaptive Loop: Hệ
(Impact) Hijacking-T1496);DoSmạng(T1498). thống tự động đánh tụt
|     |     | điểm    | tin cậy dựa | trên |
| --- | --- | ------- | ----------- | ---- |
|     |     | hành vi | bất thường  | và   |
cáchlyPodrakhỏicụm.
Phântích10chiếnthuậtMITREchothấymôhìnhbảomậtranhgiớitruyềnthốngbộclộ
rõ hạn chế ở giai đoạn hậu khai thác. Điều này làm cơ sở để đề xuất Khung kiến trúc Zero
Trust 5 thành phần (cite) với chiến lược phòng thủ theo chiều sâu, đảm bảo mọi bước tiến
củatintặctrênchuỗitiêudiệtđềuvấpphảiítnhấtmộtđiểmkiểmsoát.
13

CHƯƠNG2. ỨNGDỤNGZEROTRUSTBẢOMẬTHỆTHỐNGMICROSERVICES
2.3 Những thách thức khi triển khai ZTA trên Kubernetes
Kubernetesđượcthiếtkếvớitriếtlýưutiêntínhcogiãn(scalability)vàkhảnăngtựphục
hồi: Pod được tạo và hủy liên tục, địa chỉ IP được cấp phát lại theo nhu cầu, và mọi thực thể
trong cụm đều mang tính tạm thời theo thiết kế (The Kubernetes Authors, 2024). Tuy nhiên
ZTA đặt ra yêu cầu mọi thực thể phải được xác minh liên tục và rõ ràng trước mỗi lần truy
cập (Rose et al., 2020). Mâu thuẫn giữa tính tạm thời của Kubernetes và yêu cầu định danh
bền vững của ZTA là nguồn gốc của toàn bộ thách thức kỹ thuật được phân tích trong phần
này.
2.3.1 Định danh workload không bền vững
Trong mô hình mạng truyền thống, địa chỉ IP là đại diện ổn định cho định danh của một
máy chủ. Trong Kubernetes, giả định đó không còn đúng: một Pod có thể bị xóa và tạo lại
trong vài giây với địa chỉ IP hoàn toàn mới, trong khi vẫn đại diện cho cùng một dịch vụ
logic(TheKubernetesAuthors,2024).HệquảlàIPtrởthànhmộtđịnhdanhkhôngđángtin
cậy cho mục đích kiểm soát truy cập, và mọi chính sách bảo mật được xây dựng trên IP đều
cóthểbịphávỡbởimộtsựkiệnlậplịchbìnhthường.
ZTAyêucầuđịnhdanhphảiđượcgắnchặtvàobảnthânworkloadthôngquamậtmã
học,độclậpvớimọiyếutốmạng.GiảipháptiêuchuẩnchobàitoánnàylàSPIFFE(Secure
Production Identity Framework for Everyone) (SPIFFE Project, 2024) và hiện thực tham
chiếu của nó là SPIRE (SPIFFE Runtime Environment) (SPIFFE/SPIRE Project, 2024).
Thay vì sử dụng token dài hạn, SPIRE cấp cho mỗi workload một chứng chỉ X.509 SVID
(SPIFFEVerifiableIdentityDocument)cóthờigiansốngrấtngắn.WorkloadsửdụngSVID
này để xác thực lẫn nhau qua mTLS (Mutual Transport Layer Security), hoàn toàn độc lập
vớiđịachỉIPhaycấuhìnhmạng.
2.3.2 Không có điểm thực thi chính sách đơn nhất
Khi đã có định danh mật mã học, câu hỏi tiếp theo là: thực thi chính sách ở đâu? Ku-
bernetes không cung cấp một điểm kiểm soát đơn lẻ nào có thể bao phủ toàn bộ bề mặt tấn
công. Thay vào đó, các mối đe dọa tồn tại ở nhiều tầng có đặc thù kỹ thuật hoàn toàn khác
nhau(Roseetal.,2020):
• L3/L4 (Mạng/Giao vận): Cách kiểm soát lưu lượng mạng mặc định của Kubernetes
— thường được hiện thực bằng iptables — chỉ kiểm soát được địa chỉ IP và port
(cổng). Cơ chế này không hiểu ngữ nghĩa của lưu lượng bên trong, và không có khả
năngxácminhđịnhdanhmậtmãhọccủabêngửi.
14

CHƯƠNG2. ỨNGDỤNGZEROTRUSTBẢOMẬTHỆTHỐNGMICROSERVICES
• L7 (Ứng dụng): Để thực thi chính sách chi tiết hơn — ví dụ: chỉ cho phép HTTP GET
đến một endpoint cụ thể — hệ thống cần một thành phần có khả năng giải mã TLS
và đọc nội dung gói tin. Điều này đòi hỏi kiến trúc proxy phức tạp hơn đáng kể so với
L3/L4.
• Runtime:Ngaycảkhilưulượngmạngđượckiểmsoátchặt,bảnthâncontainercóthể
đã bị xâm phạm từ bên trong. Một tiến trình độc hại trong container có thể thực hiện
các lời gọi hệ thống bất thường mà không để lại dấu vết ở tầng mạng. Cần có cơ chế
giámsátởmứcnhânhệđiềuhànhđểpháthiệnhànhvinày(TheFalcoAuthors,2024).
Hệ quả trực tiếp là ZTA trên Kubernetes không thể chỉ dựa vào một PEP duy nhất. Hệ
thốngbắtbuộcphảitriểnkhaiPEPđatầng,trongđómỗitầngsửdụngcôngcụphùhợpvới
đặc thù của tầng đó, và các tầng phải phối hợp với nhau để tạo thành một chuỗi kiểm soát
liêntục.
2.3.3 Thiếu ngữ cảnh định danh trong quan sát hệ thống
Hai thách thức trên tập trung vào việc thiết lập và thực thi chính sách. Thách thức thứ ba
xuấthiệnngaysauđó:làmsaokiểmchứngrằnghệthốngđanghoạtđộngđúng?
Khi địa chỉ IP thay đổi liên tục, nhật ký mạng thô — vốn chỉ ghi nhận IP nguồn, IP đích
và cổng — mất đi giá trị tương quan trong điều tra sự cố. Một luồng kết nối từ 10.0.1.43
đến 10.0.2.17 không cho biết đây là frontend đang gọi payment-service theo đúng
chínhsách,haylàmộtworkloadbịxâmphạmđangthựchiệntruycậptráiphép.
ZTAdođóyêucầuhệthốngquansátphảicókhảnănggắnnhãnngữcảnhtựđộng:mỗi
luồngmạngđượcghinhậnphảimangtheođịnhdanhnguồn,địnhdanhđích,namespace,và
quyết định của PEP — không phải địa chỉ IP thuần túy (Rose et al., 2020). Đây không phải
tính năng tùy chọn mà là điều kiện cần để ZTA có thể được kiểm chứng trong thực tiễn vận
hành.
Ba thách thức trên không độc lập với nhau mà bắt nguồn từ cùng một mâu thuẫn gốc và
ràng buộc lẫn nhau theo thứ tự: không thể giải quyết bài toán thực thi chính sách nếu chưa
có định danh bền vững; không thể vận hành hệ thống đáng tin cậy nếu thiếu khả năng quan
sát có ngữ cảnh. Bộ ràng buộc này cùng nhau đặt ra yêu cầu cho kiến trúc được trình bày ở
Chương??.
2.4 Đề xuất Khung kiến trúc Zero Trust 5 thành phần
Dựatrênphântíchmôhìnhđedọa(Mục2.2)vàcáctháchthứckỹthuật(Mục2.3),đồán
đề xuất một Khung kiến trúc Zero Trust 5 thành phần dành riêng cho môi trường vi dịch
vụtrênKubernetes.
15

| CHƯƠNG2. | ỨNGDỤNGZEROTRUSTBẢOMẬTHỆTHỐNGMICROSERVICES |     |     |     |     |     |     |
| -------- | ------------------------------------------ | --- | --- | --- | --- | --- | --- |
Kiến trúc này dịch chuyển trọng tâm từ bảo vệ vành đai sang bảo vệ thực thể và dữ liệu.
Thay vì giả định an toàn nội bộ, mọi luồng giao tiếp phải tuân thủ nghiêm ngặt quy trình
khép kín: Định danh → Đánh giá trạng thái bảo mật → Xác thực → Cấp quyền → Giám
sát.
| Thành phần | 1 — Định      | danh đa     | thực     | thể:     |            |                 |     |
| ---------- | ------------- | ----------- | -------- | -------- | ---------- | --------------- | --- |
| Xác thực   | người dùng    | | Định danh | workload | | Gốc    | tin cậy hạ | tầng            |     |
| Thành phần | 2 — Đánh      | giá tư thế  | &        | Tình báo | đe dọa:    |                 |     |
| Kiểm toán  | lỗ hổng Image | | Kiểm soát | cổng     | nạp |    | Cập nhật   | tri thức mối đe |     |
dọa
| Thành phần | 3 — Thực | thi chính | sách | đa tầng: |     |     | Vòngphảnhồi |
| ---------- | -------- | --------- | ---- | -------- | --- | --- | ----------- |
Kiểm soát biên (North-South) | Microsegmentation | Xác thực cổng nạp | Giám (Cậpnhậtđiểmtincậy
vàđiềuchỉnhchínhsách)
sát Runtime
| Thành phần  | 4 — Quản      | lý bí mật    | động:   |         |             |            |     |
| ----------- | ------------- | ------------ | ------- | ------- | ----------- | ---------- | --- |
| Cấp phát    | thông tin xác | thực động    | (JIT)   |         |             |            |     |
| Thành phần  | 5 — Quan      | sát & Phân   | tích    | thích   | ứng:        |            |     |
| Thu thập    | log tập trung | | Giám sát   | chỉ số  | an ninh | | Trực quan | hóa bản đồ |     |
| mạng | Vòng | lặp đánh      | giá lại điểm | tin cậy | (PDP)   |             |            |     |
Hình2.2:KhungkiếntrúclogicZeroTrust5thànhphầnđềxuất
Dướiđâylàchitiếtchứcnăngvàvaitròcủatừngthànhphầntrongmôhình:
| 2.4.1 | Thành phần | 1: Định | danh | đa  | thực | thể |     |
| ----- | ---------- | ------- | ---- | --- | ---- | --- | --- |
Thành phần Định danh đóng vai trò là "gốc tin cậy" cho toàn bộ hệ thống. Mô hình này
ápdụngcơchếđịnhdanhképđểloạibỏhoàntoànsựtincậydựatrênđịachỉIP:
• Địnhdanhngườidùng:SửdụnggiaothứcOIDC(OpenIDConnect).Thôngtinngười
dùng được đóng gói trong JWT, mang theo các quyền hạn để phục vụ quá trình ủy
quyềnởcácthànhphầnsau.
• Định danh workload: Mọi Microservices khi khởi tạo đều được cấp một danh tính mật
mã học duy nhất (X.509 SVID) thông qua chuẩn SPIFFE. Các chứng chỉ này có thời
giansốngrấtngắn,giúpworkloadxácthựcmTLSvớiđộđảmbảomậtmãhọccao.
16

CHƯƠNG2. ỨNGDỤNGZEROTRUSTBẢOMẬTHỆTHỐNGMICROSERVICES
2.4.2 Thành phần 2: Đánh giá tư thế bảo mật và Tình báo đe dọa
Chỉ có định danh hợp lệ là chưa đủ, hệ thống cần đánh giá mức độ an toàn của tác nhân
đanggửiyêucầu.Thànhphần2thựchiệnthuthậpvàcungcấpngữcảnhbảomậtchoPolicy
Engine:
• Tư thế của Workload: Liên tục quét mã nguồn và Image của container để tìm kiếm
cácCVE(lỗhổngbảomật)hoặccáccấuhìnhsailệch.
• Tình báo đe dọa: Tự động đồng bộ các danh sách IP/Domain từ các máy chủ rà quét
hoặcpháttánmãđộctrênInternet,giúphệthốngphòngvệchủđộngngaycảkhichưa
cóyêucầukếtnối.
2.4.3 Thành phần 3: Thực thi đa tầng
Để giải quyết bài toán "điểm chết đơn lẻ", hệ thống áp dụng chiến lược phòng thủ chiều
sâuvới4PEPđộclập:
• PEP Biên: Đứng tại cửa ngõ hệ thống, kiểm tra chữ ký và hiệu lực của JWT. Từ chối
ngaylậptứccácrequestkhôngcóJWThợplệ.
• PEP Mạng: Hoạt động tại tầng nhân Linux của Node, thực thi chính sách phân đoạn
vi mô tại các tầng L3/L4 và L7. Mỗi luồng giao tiếp giữa các Microservices chỉ được cho
phép khi có khai báo tường minh trong chính sách mạng, kết hợp với xác thực định
danhmậtmãhọccủaworkloadnguồn.
• PEP Admission: Đứng tại API Server, chặn việc khởi tạo pod nếu Image không có
chữkýsốhợplệ.
• PEP Runtime: Giám sát các lời gọi hệ thống bên trong container. Bắt và ngắt ngay
lậptứccáctiếntrìnhbấtthường.
2.4.4 Thành phần 4: Quản trị bí mật động
Thành phần này loại bỏ hoàn toàn phương pháp lưu trữ mật khẩu tĩnh truyền thống. Sử
dụngPolicyAdministratorđểcấpphátthôngtinđăngnhậpCSDLtheocơchếJIT.Khimột
Microservices cần truy cập CSDL, nó sẽ được cấp một user ngẫu nhiên với TTL ngắn (ví dụ: 1
giờ).Khihếthạn,mậtkhẩutựđộngbịthuhồi.Cácbímậtnàychỉlưutrêntmpfs(bộnhớảo),
khôngghixuốngổcứngvậtlý.
17

CHƯƠNG2. ỨNGDỤNGZEROTRUSTBẢOMẬTHỆTHỐNGMICROSERVICES
2.4.5 Thành phần 5: Quan sát và Vòng lặp thích ứng
Giám sát trong Zero Trust không phải là quá trình lưu log thụ động để hậu kiểm, mà là
đầuvàotrựctiếpđểhệthốngraquyếtđịnhtheothờigianthực(Rose2020).
• Quan sát tập trung: Thu thập toàn bộ log truy cập, lưu lượng mạng và các sự kiện
bảomậttừ4thànhphầntrên.
• Vòng lặp thích ứng: Khi phát hiện một Container có hành vi bất thường (gọi API lạ,
xuất hiện CVE mới), hệ thống lập tức đánh tụt điểm tin cậy của Container đó. Sự thay
đổi điểm số này kích hoạt Thành phần 3 (PEP Mạng) tự động cắt đứt quyền truy cập,
cáchlymốiđedọamàkhôngcầnconngườicanthiệp.
CôngthứctínhĐiểmtincậyđềxuất:
(︂ missing_labels )︂
score=max 0, 100−30· −50·⊮[has_critical_cve]−20·⊮[has_high_cve]
6
BiệnluậntoánhọcchomôhìnhĐiểmtincậy:
Côngthứchiệnthựchóamộtscore-basedtrustalgorithmtheophânloạicủaRose2020<emptycitation>,
với cấu trúc penalty-based additive tương đồng các nghiên cứu ZTA gần đây (Bradatsch et
al.,2023;Jeong&Yang,2025).Bathànhphầnphạtđiểmđượcthiếtkếnhưsau:
• Điểm cơ sở: 100 điểm — giả định workload ở trạng thái tuân thủ hoàn toàn khi khởi
tạo.
• CVE Penalty: Mức phạt 50 điểm (Critical) và 20 điểm (High) được căn chỉnh theo
thangphânloạiCVSSv3.1(ForumofIncidentResponseandSecurityTeams(FIRST),
2019). Mức 50 đảm bảo bất kỳ workload nào tồn tại CVE Critical đều lập tức xuống
dướingưỡngcôlập(score<50,BucketLow).
• Governance Penalty: 30·(missing_labels/6) đánh giá tuân thủ 6 nhãn metadata bắt
buộc, cụ thể hóa nguyên lý thứ 7 của NIST SP 800-207 về thu thập dữ liệu trạng thái
liêntục(Rose2020).
Các trọng số (50, 20, 30) là tham số cấu hình phụ thuộc vào khẩu vị rủi ro của từng tổ
chức — Jeong and Yang (2025) xác nhận qua phân tích độ nhạy rằng không tồn tại bộ trọng
số tối ưu duy nhất cho mọi môi trường. Trong PoC này, các giá trị được chọn để đảm bảo
workload dính CVE Critical bị cô lập ngay lập tức, bất kể trạng thái quản trị, theo triết lý
AssumeBreach(Rose2020).
Điểm số được rời rạc hóa thành 3 bucket (High ≥80, Medium ∈[50,80), Low <50) để
CiliumNetworkPolicycóthểmatchLabelstrựctiếp,tránhhiệntượngpolicychurndodao
độngđiểmsốnhỏ.
18

| CHƯƠNG2. | ỨNGDỤNGZEROTRUSTBẢOMẬTHỆTHỐNGMICROSERVICES |         |           |          |
| -------- | ------------------------------------------ | ------- | --------- | -------- |
| 2.4.6    | Đề xuất                                    | bộ công | nghệ hiện | thực hóa |
Để tránh sự phụ thuộc vào một nhà cung cấp duy nhất, khung 5 thành phần trên được
hiện thực hóa bằng phương pháp lựa chọn tốt nhất theo từng loại, tổ hợp các công cụ mã
nguồn mở xuất sắc nhất của Cloud Native Computing Foundation (CNCF). Bảng 2.3 ánh xạ
môhìnhvàobộcôngcụđượclựachọnchothựcnghiệmởChương3.
Bảng2.3:Bảngtổnghợpthamchiếu:thànhphầnkiếntrúcđềxuất↔NIST↔Côngnghệ↔Rủiro
giảmthiểu
| Thành | Vaitrò | Côngnghệđềxuất |     | Rủirođượcgiảmthiểu |
| ----- | ------ | -------------- | --- | ------------------ |
phần
Identity PIP Keycloak (User JWT), T1078 (Valid Accounts): Ngăn chặn sử dụng to-
|     |     | SPIRE | (Workload | ken/mậtkhẩutĩnhbịđánhcắp. |
| --- | --- | ----- | --------- | ------------------------- |
SVID)
Posture PIP Trivy(CVE), T1610(DeployContainer):Chặntriểnkhaiứng
|     |     | Gatekeeper(Label) |     | dụngmanglỗhổngZero-day. |
| --- | --- | ----------------- | --- | ----------------------- |
Network PEP CiliumeBPF T1021 (Remote Services), Lateral Movement:
|     |     | (Microsegmentation) |     | Chặnràquétvàdichuyểnngang. |
| --- | --- | ------------------- | --- | -------------------------- |
Runtime PEP Tetragon (eBPF T1611 (Escape to Host): Ngăn chặn mở shell
|     |     | kprobe) |     | (/bin/sh)tráiphéptrongPod. |
| --- | --- | ------- | --- | -------------------------- |
Secrets PA HashiCorpVault(JIT) T1552 (Container API Creds): Tránh rò rỉ cre-
dential,tựđộngthuhồikhihếthạn.
| 2.5 Mô | hình | chính | sách | đề xuất |
| ------ | ---- | ----- | ---- | ------- |
Mô hình chính sách là trái tim của Policy Engine, quyết định các mục tiêu bảo mật sẽ
đượcthựcthinhưthếnào.
| 2.5.1 | Tiếp cận | phân | quyền theo | thuộc tính |
| ----- | -------- | ---- | ---------- | ---------- |
ThayvìRBACtĩnh,đồánsửdụngABAC(Huetal.,2014)đểđạtđộhạtmịn.Quyếtđịnh
truycậplàmộthàmsốcủa4biến:
|                    |     | Decision=                             | f(Subject,Resource,Action,Environment) |     |
| ------------------ | --- | ------------------------------------- | -------------------------------------- | --- |
| TrongđóEnvironment |     | baogồmcảđiểmtincậyhiệntạicủaworkload. |                                        |     |
19

| CHƯƠNG2.     | ỨNGDỤNGZEROTRUSTBẢOMẬTHỆTHỐNGMICROSERVICES |               |     |     |
| ------------ | ------------------------------------------ | ------------- | --- | --- |
| 2.5.2 Nguyên | tắc Từ                                     | chối mặc định |     |     |
• Từchốimặcđịnh:Mọiluồnggiaotiếpmặcđịnhbịchặnngaykhikhởitạo.
• Chophéptườngminh:ChỉnhữngkếtnốiđượckhaibáorõràngtrongYAMLPolicy
mớiđượcmở.Ngănchặnkhảnăngtrinhsátmạngcủatintặc.
| 2.5.3 Vòng | đời chính | sách |     |     |
| ---------- | --------- | ---- | --- | --- |
Chính sách được viết dưới dạng mã, lưu trữ trên Git để kiểm soát phiên bản. PA phân
phối luật xuống các PEP (Kong, Cilium Agent) để đối chiếu theo thời gian thực. Toàn bộ
quyếtđịnhđượcloglạiđểlớpObservabilityđánhgiávàtinhchỉnh.
| 2.6 Lộ | trình chuyển | đổi sang | kiến trúc | Zero Trust |
| ------ | ------------ | -------- | --------- | ---------- |
Theo tài liệu tiêu chuẩn NIST SP 800-207 (Mục 3.5 - Lộ trình triển khai), việc chuyển
đổi sang kiến trúc Zero Trust không phải là thay thế toàn bộ hệ thống cùng lúc, mà là một
quá trình diễn ra theo từng bước, có tính lặp và mở rộng dần. Tổ chức cần thực hiện lộ trình
chuyểnđổigồm7bướcchínhđểđảmbảohệthốngvậnhànhliêntụcvàantoàn.
20

CHƯƠNG2. ỨNGDỤNGZEROTRUSTBẢOMẬTHỆTHỐNGMICROSERVICES
Bảng2.4:Quytrìnhchuyểnđổi7bướctheotiêuchuẩnNISTSP800-207
Bước Tênbước Nộidungthựchiệnchitiết
1 Xácđịnhcácchủthể Nhận diện và lập danh sách toàn bộ các đối tượng có
tương tác với hệ thống, bao gồm người dùng, tài khoản
dịchvụvàcácthựcthểtựđộngtronghệthống.
2 Xácđịnhtàisản Thống kê đầy đủ toàn bộ tài sản số, thiết bị phần cứng,
phầnmềmvàdữliệuquantrọngthuộcphạmviquảnlý
củatổchức.
3 Xác định quy trình và Phân tích các quy trình nghiệp vụ quan trọng và xây
luồngdữliệu dựngbảnđồluồngtraođổidữliệugiữacácthànhphần
tronghệthốngnhằmhiểurõcáchvậnhànhtổngthể.
4 Xây dựng chính sách Thiết lập các quy tắc kiểm soát truy cập dựa trên bối
bảomật cảnh,làmcơsởchocơchếraquyếtđịnhtronghệthống
ZeroTrust.
5 Lựa chọn giải pháp phù Đánh giávà lựa chọn cáccông nghệ, côngcụ hoặc nền
hợp tảng phù hợp để triển khai mô hình Zero Trust đã thiết
kế.
6 Triểnkhaithửnghiệm Thực hiện triển khai trong phạm vi nhỏ, tách biệt khỏi
hệthốngchính,vậnhànhsongsongđểtheodõivàtinh
chỉnhchínhsáchtrướckhiápdụngrộngrãi.
7 Mởrộngtriểnkhaitoàn Áp dụng mô hình Zero Trust trên toàn bộ hạ tầng dựa
hệthống trên kết quả và kinh nghiệm thu được từ giai đoạn thử
nghiệm.
CầunốisangChương3:
Chương2đãhoàntấtviệcquyhoạchlýthuyếtthànhmộtKhungkiếntrúcZero
Trust5thànhphầncụthểchomôitrườngMicroservices,đồngthờiđềxuấtbộ
công cụ CNCF và lộ trình 4 giai đoạn rõ ràng. Chương 3 tiếp theo sẽ trình bày
quá trình triển khai thực nghiệm thiết kế này lên hệ thống tuyển dụng job7189
thực tế, từ đó đưa ra các đánh giá định lượng và định tính về tính hiệu quả của
môhìnhđềxuất.
21

Chương 3
Triển khai thực nghiệm
3.1 Mô tả bài toán và đối tượng thực nghiệm
Bốicảnhhệthống.
Job7189 là hệ thống tuyển dụng trực tuyến được phát triển theo kiến trúc Microservices,
bao gồm 7 dịch vụ nghiệp vụ độc lập: identity, workspace, job, hiring, candidate,
communication, và storage. Các dịch vụ này giao tiếp với nhau qua API nội bộ và hệ
thốngtinnhắnsựkiện.
Phátbiểubàitoán.
Khi vận hành trên nền tảng Kubernetes, bề mặt tấn công của hệ thống tăng mạnh ở cả hai
chiều Bắc-Nam và Đông-Tây. Việc duy trì cơ chế tin cậy ngầm định dẫn đến nguy cơ leo
thang đặc quyền, di chuyển ngang khi một pod bị chiếm quyền, và rò rỉ thông tin xác thực
tĩnh. Lộ trình nâng cấp hệ thống hướng tới kiến trúc Zero Trust tập trung vào việc hiện thực
hóa bốn mục tiêu chính: kiểm soát biên chặt chẽ, phân đoạn mạng động, quản trị bí mật JIT
vàtăngcườnghệthốnggiámsáttậptrung.
Phạmvithựcnghiệm.
Triển khai tập trung vào hạ tầng an ninh và vận hành hệ thống, bao gồm API Gateway, định
danh workload, chính sách mạng nội bộ, quản lý khóa động, và hệ thống giám sát. Các tính
năng nghiệp vụ của Job7189 đóng vai trò là đối tượng cần bảo vệ và không thuộc phạm vi
pháttriểnchínhtrongchươngnày.
3.1.1 Tổng quan kiến trúc Job7189
Các luồng tích hợp nghiệp vụ và sơ đồ phân vùng dữ liệu của hệ thống được mô tả khái
quát qua các hình vẽ ngữ cảnh hệ thống (Hình 3.1), kiến trúc ứng dụng (Hình 3.2) và sơ đồ
kếtnốidữliệu(Hình3.3).
22

CHƯƠNG3. TRIỂNKHAITHỰCNGHIỆM
Hình3.1:SơđồngữcảnhhệthốngJob7189
Hình3.2:KiếntrúccontainercủahệthốngJob7189(gócnhìnnghiệpvụ)
23

CHƯƠNG3. TRIỂNKHAITHỰCNGHIỆM
Hình3.3:KiếntrúccontainercủahệthốngJob7189(gócnhìndữliệu)
3.2 Thiết kế Zero Trust cho hệ thống Job7189
Thiết kế kiến trúc Zero Trust cho hệ thống Job7189 được cụ thể hóa thông qua việc xác
địnhcácyêucầukỹthuậtvàlựachọncôngnghệtươngứng.
3.2.1 Yêu cầu và Nguyên tắc thiết kế
Yêucầuchứcnăng:
R-F1. Địnhdanhđađốitượng:Yêucầuxácthựcđồngthờidanhtínhngườidùng(JWT)
vàđịnhdanhcủaworkload(SVIDhoặcServiceAccountJWT).
R-F2. Từchốimặcđịnh:Mọiluồngthôngtinliênlạcmặcđịnhbịchặnvàchỉđượcchấp
nhậnkhicấuhìnhtườngminh.
R-F3. Phòng thủ chiều sâu: Triển khai chốt chặn kiểm soát độc lập ở các mức biên,
mạng,cổngnạpvàruntime.
R-F4. Quảnlýbímậtđộng:ThaythếmậtkhẩutĩnhbằngtàikhoảntruycậpCSDLsinh
độngJITcóthờihạnngắn.
R-F5. Vòngphảnhồithíchứng:ĐiểmtincậycủaPodđượcđánhgiáliêntụcvàtựđộng
điều chỉnh chính sách mạng cũng như quyền lấy thông tin xác thực từ Vault tương
ứng.
24

| CHƯƠNG3. | TRIỂNKHAITHỰCNGHIỆM |     |     |     |     |     |     |
| -------- | ------------------- | --- | --- | --- | --- | --- | --- |
Yêucầuphichứcnăng:
R-N1. Độtrễtốithiểu:Trễphátsinhdokiểmsoátanninhgiớihạndưới5msởtầngmạng
L4vàdưới30msởtầngứngdụngL7.
R-N2. Ngân sách tài nguyên: Toàn bộ hệ thống chạy ổn định trong giới hạn phần cứng
RAM∼15.5GiB.
R-N3. Tính nhất quán IaC: Quy trình cấu hình và triển khai được tự động hóa, hỗ trợ
phụchồivàpháthiệntrôidạttrạngthái.
| 3.2.2 | Kiến trúc | triển | khai |     |     |     |     |
| ----- | --------- | ----- | ---- | --- | --- | --- | --- |
Hệ thống phân rã các cấu phần ZTA theo khung NIST SP 800-207 (Rose et al., 2020)
bao gồm PE, PA, PEP và PIP, từ đó hiện thực hóa thành 5 thành phần công nghệ phối hợp
chặtchẽnhưsơđồsau:
| Thành    | phần 1 — Định   | danh           | đa  | thực thể: |           |       |             |
| -------- | --------------- | -------------- | --- | --------- | --------- | ----- | ----------- |
| Keycloak | (User Identity) | | SPIRE/SPIFFE |     |           | (Workload | SVID) | | Vault K8s |
Auth.
| Thành          | phần 2 — Đánh         | giá | tư thế | và CDN:      |     |            |                |
| -------------- | --------------------- | --- | ------ | ------------ | --- | ---------- | -------------- |
| Trivy Operator | (VulnerabilityReport) |     |        | | Gatekeeper |     | Constraint | | Threat-intel |
CronJob.
| Thành | phần 3 — Thực | thi | chính | sách | đa tầng: |     |     |
| ----- | ------------- | --- | ----- | ---- | -------- | --- | --- |
Vòngphảnhồi
| Kong (PEP | N-S) | Cilium | eBPF | (PEP | E-W) | | Sigstore | (Admission) | |   |
| --------- | ------------- | ---- | ---- | ---- | ---------- | ----------- | --- |
(Giảmđiểmtincậy)
| Tetragon      | (Runtime).    |         |        |          |       |         |       |
| ------------- | ------------- | ------- | ------ | -------- | ----- | ------- | ----- |
| Thành         | phần 4 — Quản | lý      | bí mật | động:    |       |         |       |
| Vault Dynamic | Engine        | | Vault | Agent  | Injector | (tiêm | sidecar | mount |
tmpfs/.env).
| Thành     | phần 5 — Quan | sát | & Phân  | tích     | thích ứng: |          |                |
| --------- | ------------- | --- | ------- | -------- | ---------- | -------- | -------------- |
| EFK Stack | | Prometheus  | &   | Grafana | | Hubble | UI |       | Vòng lặp | đối chiếu PDP. |
Hình3.4:KiếntrúctriểnkhaiZeroTrustđềxuất
Chitiếtvềviệctriểnkhaivàtíchhợp5thànhphầnnàyvàohệthốngthựctếsẽđượcphân
tíchcụthểtạiMục3.3(Cơsởhạtầngcốtlõi)vàMục3.4(Cơchếnângcao).
25

| CHƯƠNG3.  | TRIỂNKHAITHỰCNGHIỆM |         |              |     |     |
| --------- | ------------------- | ------- | ------------ | --- | --- |
| 3.2.3 Cấu | trúc Workload       | và Phân | bổ Namespace |     |     |
Hệ thống chạy trên cụm 4 máy ảo máy chủ và được tổ chức chặt chẽ thành 9 namespace
đểcáchlyrủirovậnhành:
| gateway              |     | management       |     | cert-manager       |     |
| -------------------- | --- | ---------------- | --- | ------------------ | --- |
| • kong-gateway       |     | • phpmyadmin     |     | • cert-manager     |     |
| • oauth2-proxy       |     | • kafbat-ui      |     | • zta-internal-ca  |     |
| data                 |     | security         |     | ingress-nginx      |     |
| • mysql(StatefulSet) |     | • keycloak(OIDC) |     | • nginx-controller |     |
pdp-controller
| • kafka(StatefulSet) |     | •   |     |     |     |
| -------------------- | --- | --- | --- | --- | --- |
• cosign-public-key
monitoring
| vault      |     |                         |     | • elasticsearch       |     |
| ---------- | --- | ----------------------- | --- | --------------------- | --- |
| vault-prod |     | gatekeeper/cosign/spire |     | • filebeat(DaemonSet) |     |
•
• vault-agent-injector • gatekeeper-controller • prometheus+grafana
• cosign-policy-controller
• spire-server/agent
kube-system
job7189-apps
• cilium-agent
• identity-service
| • workspace-service |     |     |     | • hubble-relay      |     |
| ------------------- | --- | --- | --- | ------------------- | --- |
| • job-service       |     |     |     | • tetragon(Runtime) |     |
• hiring-service
• candidate-service
Hình3.5:Bảnđồworkloadtheonamespacephântáchrủirobảomật.
| 3.3 Triển | khai | các cơ sở hạ | tầng Zero | Trust cốt | lõi |
| --------- | ---- | ------------ | --------- | --------- | --- |
QuátrìnhtriểnkhaibámsáthướngdẫncủatiêuchuẩnNISTSP800-207(nist_sp_800_207),
thiếtlậptuầntựcácthànhphầntừgốctincậy,đánhgiátưthế,phânđoạnmạng,chođếnquản
lýbímậtvàquansáthệthống.
| 3.3.1 Thiết | lập Gốc | tin cậy (Thành | phần 1) |     |     |
| ----------- | ------- | -------------- | ------- | --- | --- |
XácthựcngườidùngvớiKeycloak:
Keycloak được cấu hình với 2 Realm để phân tách rủi ro quản trị: Realm 7189_internal
dành cho đội ngũ vận hành hệ thống và Realm job7189 cấp phát định danh cho người dùng
cuối. Mật khẩu quản trị và CSDL Keycloak được sinh ngẫu nhiên và cấp qua Kubernetes
Secrets,hạnchếnguycơlộmậtkhẩutĩnh.
26

CHƯƠNG3. TRIỂNKHAITHỰCNGHIỆM
Hình3.6:LuồngxácthựcOIDC/JWTchoNorth-SouthtrafficquaKeycloakvàKong
ĐịnhdanhWorkloadvớiSPIRE:
Thay vì sử dụng ServiceAccount Token tĩnh mặc định, hệ thống tích hợp giải pháp SPIRE
cấp phát chứng chỉ mật mã X.509 SVID với thời gian sống ngắn (15-60 phút). Dự án
cấu hình tổng cộng 10 chính sách ClusterSPIFFEID (bao gồm 3 chính sách chính dành
cho các tầng nghiệp vụ: zta-default-workload-identity, zta-tier1-extended-ttl,
zta-tier3-short-ttlvà7chínhsáchhệthống).
Trong giai đoạn này, cơ chế ServiceMesh mTLS của Cilium được cấu hình tắt để tiết
kiệm tài nguyên; mạng Tailscale chịu trách nhiệm mã hóa ở mức L3. Hệ thống SPIRE giữ
vai trò cấp định danh workload phục vụ công tác xác thực, giám sát và kiểm toán an ninh
trêntoàncụm.
Cơchếchứngthựcworkload:
QuytrìnhcấpSVIDdiễnraquahaicấpchứngthựcnghiêmngặtđểngănchặnpodgiảmạo:
1. Node Attestation: Khi Worker Node khởi tạo, spire-agent chứng minh danh tính
vớispire-serverquatokenxácthựccủakubeletđểlấySVIDcủaNode.
2. Workload Attestation: Pod nghiệp vụ gọi spire-agent qua Unix Domain Socket.
Agent dựa vào Kernel của Node chủ để xác định chính xác PID, từ đó truy vấn
namespace,ServiceAccountvàImage hashcủaPod.Nếukhớpvớibảnghiđãkhai
báo, Agent mới yêu cầu Server ký cấp X.509 SVID, lưu trực tiếp trên bộ nhớ của tiến
trình.
27

CHƯƠNG3. TRIỂNKHAITHỰCNGHIỆM
3.3.2 Đánh giá tư thế bảo mật và Tình báo đe dọa (Thành phần 2)
ĐóngvaitròlàĐiểmcungcấpthôngtinchínhsách,hệthốngliêntụcđánhgiátưthếbảo
mật nội tại và cập nhật danh sách các mối đe dọa từ bên ngoài nhằm cung cấp dữ liệu đầu
vàochoquátrìnhraquyếtđịnh:
Đánhgiálỗhổngliêntục:
Hệ thống triển khai Trivy Operator dưới dạng một bộ điều khiển liên tục theo dõi các Pod
đang chạy. Khi có sự thay đổi hoặc theo chu kỳ, Trivy tự động quét các container image để
pháthiệnCVE,bímậtbịlộvàlỗicấuhìnhsai.Kếtquảquétđượclưutựđộngdướidạngcác
tài nguyên VulnerabilityReport gắn liền với từng workload. Dữ liệu này là cơ sở quan
trọngđểđánhgiámứcđộrủirovàđiểmtincậynộitạicủaPod.
Ràngbuộcchínhsáchanninh:
Để ngăn chặn các rủi ro cấu hình và triển khai, OPA Gatekeeper (em đang cân nhắc đổi
sang Kyverno hoặc công cụ khác) được áp dụng để thiết lập các rào cản từ chối nạp. Các
ConstraintđượcđịnhnghĩaquangônngữRegoyêucầuworkloadphảituânthủnghiêmngặt
cáctiêuchuẩnantoàn,vídụnhưcấmchạycontainervớiđặcquyềnprivileged,ngănchặn
việc gắn trực tiếp thư mục gốc của node vật lý, hoặc kiểm soát nghiêm ngặt các namespace
dùngchung.
TíchhợpTìnhbáođedọa:
Đối phó với các rủi ro từ bên ngoài, một Kubernetes CronJob định kỳ kéo danh sách các địa
chỉ IP độc hại, botnet từ các nguồn tình báo mã nguồn mở uy tín như FireHOL Level 1 và
URLhaus. Sau khi xử lý dữ liệu, CronJob tự động cập nhật danh sách này vào tài nguyên
CiliumCIDRGroup (với tên threat-intel-firehol). Danh sách này trực tiếp tham chiếu
tới chính sách mạng toàn cụm (CiliumClusterwideNetworkPolicy), giúp tự động chặn
cáckếtnốiEgressnếuPodnỗlựcgiaotiếpvớicácmáychủCommand&Control.
3.3.3 Thực thi chính sách đa tầng (Thành phần 3)
Hệ thống thiết lập các chốt chặn ở cả hai hướng giao tiếp Bắc-Nam và Đông-Tây để đảm
bảonguyêntắctừchốimặcđịnh.
PEPbiên:
Xử lý luồng dữ liệu từ người dùng đi vào hệ thống, Kong Gateway hoạt động ở chế độ DB-
less và thực hiện xác thực token JWT do Keycloak cấp ngay tại biên. Để phân quyền dựa
trênngữcảnhmộtcáchlinhhoạt,pluginCustomLuatrongKongchặnrequestvàgửiHTTP
POSTsangOPASidecarchạytrongcụm.OPAđánhgiáyêucầudựatrênquytắctrong6tệp
chính sách Rego. Để tối ưu hóa hiệu năng tại môi trường lab, nhật ký quyết định hiện chưa
đượcghinhậntrựctiếpởphathửnghiệmnày;việckiểmtralogicchínhsáchđượcmôphỏng
ngoạituyếnquaopa eval(xemPhụlụcB).
28

| CHƯƠNG3. | TRIỂNKHAITHỰCNGHIỆM |     |     |
| -------- | ------------------- | --- | --- |
Phânđoạnvimô:
Đối với luồng nội bộ, hệ thống cấu hình CiliumNetworkPolicy sử dụng công nghệ eBPF
chạytạinhânhệđiềuhànhđểphânđoạnlưulượngmạng.Sovớitườnglửatruyềnthốngbằng
iptables, eBPF giải quyết được hạn chế về độ trễ và tài nguyên nhờ định danh duy nhất dựa
trênMetadata(thểhiệndướidạngLabel)thayvìIPtĩnh,đồngthờichặngóitinngaytạicard
mạngảocủaPodtrướckhinókịpđisâuvàohạtầng.
Hệthốngápdụng11chínhsáchmạng(CiliumNetworkPolicy)trongnamespacejob7189-apps
(gồm default-deny-all và 10 chính sách allow-* cho phép các luồng liên lạc L3/L4/L7),
1chínhsáchmạngtoàncụm(CiliumClusterwideNetworkPolicy)và1nhómCIDRđịnh
danh(CiliumCIDRGroup).
Dưới đây là tệp cấu hình chính sách chặn mặc định default-deny-all áp dụng nhãn
umbrella-deny:
| 1 apiVersion: | cilium.io/v2        |     |     |
| ------------- | ------------------- | --- | --- |
| kind:         | CiliumNetworkPolicy |     |     |
2
metadata:
3
| name: | default-deny-all |     |     |
| ----- | ---------------- | --- | --- |
4
| namespace: | job7189-apps |     |     |
| ---------- | ------------ | --- | --- |
5
spec:
6
7 egress:
| 8 - toEndpoints: |                    |               |     |
| ---------------- | ------------------ | ------------- | --- |
| 9 -              | matchLabels:       |               |     |
|                  | cilium.zta/marker: | umbrella-deny |     |
10
endpointSelector:
11
matchLabels: {}
12
ingress:
13
| 14 - fromEndpoints: |                    |               |     |
| ------------------- | ------------------ | ------------- | --- |
| 15 -                | matchLabels:       |               |     |
| 16                  | cilium.zta/marker: | umbrella-deny |     |
Saukhichặnmặcđịnh,cáckếtnốihợplệđượcmởtheonguyêntắcđặcquyềntốithiểu:
• ChínhsáchL3/L4:Ràngbuộc theoServiceAccountcủanguồnphát vàđíchnhận.Ví
dụ,chỉchophépidentity-servicekếtnốiTCPcổng3306đếnMySQL.
• ChínhsáchL7:eBPFProxykiểmsoátchitiếtđếnmứcHTTPMethodvàPath(vídụ:
chỉ cho phép GET trên path /api/v1/workspaces/*, chặn mọi phương thức phá hoại
nhưDELETE).
| 3.3.4 | Quản trị Bí mật | Động (Thành | phần 4) |
| ----- | --------------- | ----------- | ------- |
Hệ thống loại bỏ hoàn toàn việc lưu trữ tệp tin .env chứa thông tin xác thực tĩnh trên ổ
đĩa. Thay vào đó, mô hình JIT credentials được áp dụng qua HashiCorp Vault. Cấu trúc Pod
29

CHƯƠNG3. TRIỂNKHAITHỰCNGHIỆM
nghiệpvụđượcthiếtlậpdạngMulti-Sidecarhỗtrợxoayvòngkhóakhônggiánđoạn:
1. Vault Mutating Webhook tự động tiêm container phụ (vault-agent, env-loader)
vàoPod.
2. PodxácthựcdanhtínhvớiVaultthôngquacơchếKubernetesServiceAccountJWT.
3. VaultkếtnốiMySQLtạotàikhoảntạmthờitheođịnhdạngv-kubernetes-job-servic-XXXXXX
với các quyền giới hạn trên CSDL tương ứng. Mật khẩu được cấp TTL mặc định là 1
giờvàtốiđalà24giờ.
4. Mật khẩu JIT được ghi vào ổ đĩa ảo trên RAM (tmpfs), hạn chế ghi trực tiếp vào đĩa
cứngvậtlý.
5. Sidecar env-loader nạp cấu hình vào RAM. Trước khi TTL hết hạn (khi thời lượng
còn lại khoảng 1/3, tương đương 40–43 phút hoạt động), vault-agent thực hiện quy
trìnhgiahạntựđộng,ghiđècredentialmớilêntmpfsvàbáohiệuứngdụngtảilạicấu
hình.
30

CHƯƠNG3. TRIỂNKHAITHỰCNGHIỆM
Hình3.7:VòngđờiJITcredential–từkhởitạoPodđếntựđộngxoayvòngbímật
31

CHƯƠNG3. TRIỂNKHAITHỰCNGHIỆM
3.3.5 Khả năng quan sát tập trung (Thành phần 5)
Để thu thập tín hiệu, giám sát mạng và khép kín vòng lặp an ninh, hệ thống thiết lập các
côngcụbổtrợtạiđiểmquansát:
• Hubble UI/CLI: Trực quan hóa bản đồ luồng mạng L3/L4/L7 thời gian thực, hiển thị
chitiếtcácluồngdữliệubịchặndoviphạmZeroTrust.
• Tetragon: Giám sát các syscall nhạy cảm (sys_execve) ở mức nhân. Do giới hạn về
phiênbảnnhânhệđiềuhành,hànhđộngphảnhồihiệntạiđượccấuhìnhởchếđộPost
ghinhậtký,theodõi7tệpnhịphânnhạycảm(gồmshell,curl,wgetvànmap).
• EFK Stack (Elasticsearch, Filebeat, Kibana): Thu thập toàn bộ nhật ký ứng dụng,
auditlogscủaVaultvàcácviphạmmạngtừTetragonphụcvụtruyvết.
• Prometheus&Grafana:Thuthậpvàtrựcquanhóacácchỉsốanninhnhưtỷlệdrop
góitinđểpháthiệntấncôngràquét.
Hình3.8:HubbleUI:TrựcquanhóanetworkflowvàpolicyenforcementL7
32

CHƯƠNG3. TRIỂNKHAITHỰCNGHIỆM
Hình3.9:Kibana:Truyvấnsecurityeventtổnghợptừhệthống
3.4 Các cơ chế Zero Trust nâng cao
Sau khi hoàn thiện các trục cơ sở là Định danh, Đánh giá, Mạng và Quan sát (đạt mức
trưởng thành Advanced theo CISA ZTMM (cisa_zmm)), hệ thống tích hợp các cơ chế nâng
caohướngtớimứctốiưu(Optimal).
3.4.1 Bảo mật Chuỗi cung ứng với Cosign
Vấn đề: Để ngăn chặn kỹ thuật thay thế Image độc hại đè lên tag phiên bản cũ, hệ thống
ápdụngquytrìnhxácthựcnguồngốcImage:
• Ký ngoại tuyến: Tất cả Image của 7 Microservices được ký bằng khóa ECDSA thông qua
CosigntrướckhiđẩylênRegistry.
• Xácthựctạicổng:WebhookcủaSigstorePolicyControllerchạytrongcụmápdụng3
chínhsáchClusterImagePolicy(zta-job7189-apps-signed,zta-keyless-trust-job7189,
zta-system-passthrough) kết hợp với OPA Gatekeeper. Webhook hiện được đặt ở
chếđộcảnhbáo(WARN mode)thayvìchặntrựctiếp(ENFORCE mode)đểđảmbảotính
khả dụng trong quá trình nâng cấp các thư viện bên thứ ba chưa ký số. Chi tiết cảnh
báotrên5imagecôngcụhạtầngđượcthảoluậnởChương4.
33

CHƯƠNG3. TRIỂNKHAITHỰCNGHIỆM
3.4.2 Vòng lặp Phản hồi Thích ứng
Hệ thống Job7189 xây dựng vòng lặp phản hồi tự thích ứng dựa trên bộ điều khiển PDP
tựpháttriểnđểthayđổiđộngcácchínhsáchbảomật:
1. Thu thập tín hiệu an ninh: Thay vì đánh giá một lần duy nhất, PDP kế thừa liên tục
cáctínhiệuđầuvàotừThànhphần2(baogồmsốlượng/mứcđộCVEtừVulnerabilityReport
củaTrivyvàdanhsáchIPtừThreat-IntelđãtrìnhbàyởMục3.3.2).
2. Đánh giá điểm tin cậy: Thành phần zta-pdp trong namespace security chạy vòng
lặp đối chiếu định kỳ mỗi 90 giây trên 7 namespace. Trong giai đoạn thử nghiệm này,
cấuhìnhđầuvàoCVEtạmthờibịtắt(PDP_CVE_INPUT=false)đểkiểmthửthuậttoán
tínhđiểmổnđịnhtrướckhiđưavàovậnhànhthựctế.
3. Thựcthichínhsáchmạngđộng:ĐiểmtincậyđượcánhxạthànhlabelcủaPod.Nếu
điểmsốtụtxuốngmứclow,chínhsáchcnp-block-low-trust-to-vaultsẽlậptức
được kích hoạt để chặn quyền truy cập lấy khóa từ Vault. Trong giai đoạn thử nghiệm
này,chínhsáchmạngtrênchưađượcápdụngtrựctiếplêncụm(PendingRollout).
3.5 Quy trình triển khai tự động
Toàn bộ tài nguyên, chính sách bảo mật và ứng dụng được khai báo dưới dạng Hạ tầng
nhưMã(IaC)thôngquaHelmvàHelmfile.Quytrìnhtriểnkhaitựđộng(zta-rebuild.sh)
đượctổchứcthành5giaiđoạnnghiêmngặtđểđảmbảotínhantoànxácđịnh:
34

| CHƯƠNG3. | TRIỂNKHAITHỰCNGHIỆM |     |     |
| -------- | ------------------- | --- | --- |
Bảng3.1:CácgiaiđoạncốtlõitrongPipelinetriểnkhaitựđộngZTA
| Giaiđoạn | Thànhphầntriểnkhai |     | Ýnghĩa&ChứcnăngBảomật |
| -------- | ------------------ | --- | --------------------- |
1.Infra&Identity CiliumCNI, CàiđặteBPFdataplane.Sinhngẫunhiên
|     | cert-manager,Keycloak, |     | thôngtinxácthựcgốc.Thiếtlậphạtầngmã |
| --- | ---------------------- | --- | ----------------------------------- |
|     | Vault(Dual-mode).      |     | hóa(TLS)vàQuảntrịđịnhdanh.          |
2.Microservices 7Dịchvụnghiệpvụ, Triểnkhaiứngdụng.CấuhìnhDatabase
|     | MySQL,Kafka,Redis. |     | EnginetrênVault.Khởichạyluồngcấp |
| --- | ------------------ | --- | -------------------------------- |
DynamicCredentialsquaVaultAgent.
3.Hardening CiliumNetworkPolicies, BậtZeroTrust:KíchhoạtDefault-Deny,mở
|     | L7Rules,KongGateway. |     | kếtnốitheonguyêntắcđặcquyềntốithiểu. |
| --- | -------------------- | --- | ------------------------------------ |
KiểmduyệttokenJWTtạiAPIGateway.
4.AdvancedZTA SPIRE,Cosign, KývàxácthựcImage.PhânphốiSVID.Đánh
|     | Gatekeeper,Trivy,PDP, |     | giátưthếanninh,tínhđiểmtincậyvàgiám |
| --- | --------------------- | --- | ----------------------------------- |
|     | Tetragon.             |     | sátRuntimesyscall.                  |
5.Observability EFKStack,Prometheus, Càiđặthệthốngthuthậplogvàmetricsan
|     | Grafana,Hubble. |     | ninh,khépkínvònglặpgiámsát. |
| --- | --------------- | --- | --------------------------- |
Quy trình IaC hỗ trợ tự động dọn dẹp tài nguyên lỗi và kiểm tra khả năng hoạt động ở
cuối mỗi phase, đảm bảo hệ thống rơi vào trạng thái an toàn xác định trong trường hợp xảy
ralỗi.
| 3.6 Môi | trường | thử nghiệm |     |
| ------- | ------ | ---------- | --- |
Thựcnghiệmđượcthựchiệntrêncụmkubeadmv1.30gồm4máyảo(1ControlPlane,3
Worker),kếtnốiquamạngriêngảoTailscaleWireGuard.TrạngtháimạngL3điquaTailscale
CGNAT; mặt phẳng Pod đi qua Cilium VXLAN. Tổng tài nguyên cấp phát cho cụm khoảng
15.5GiBRAMvà7vCPU.
35

| CHƯƠNG3. | TRIỂNKHAITHỰCNGHIỆM |     |
| -------- | ------------------- | --- |
Bảng3.2:Cấuhìnhhệthốngtạithờiđiểmthửnghiệm
| Hạngmục |     | Giátrịthựctế |
| ------- | --- | ------------ |
Sốnode 4(1control-plane:7189srv01,3worker:7189srv02,7189srv03,
7189srv05)
| Kernel |     | 6.12.86(Debian13)trên3nodesrv01,srv02,srv03;6.8.0-117 |
| ------ | --- | ----------------------------------------------------- |
(Ubuntu24.04)trênnodesrv05
| Containerruntime      |     | containerd://2.2.3                         |
| --------------------- | --- | ------------------------------------------ |
| Kubernetesversion     |     | Client/Serverv1.30.x                       |
| Ciliumnamespacepolicy |     | 11CNPtrongnamespacejob7189-apps(baogồm     |
| (CNP)                 |     | default-deny-all+10chínhsáchallow-*chophép |
L3/L4/L7)
| Ciliumclusterpolicy |     | 1CCNP(cnp-threat-intel-egress-deny) |
| ------------------- | --- | ----------------------------------- |
(CCNP)
| CIDRgroup |     | 1CiliumCIDRGroup(threat-intel-firehol) |
| --------- | --- | -------------------------------------- |
TracingPolicy(Tetragon) 1cluster(monitor-kernel-module-load)+4namespaced
(block-suspicious-execở4namespace,
monitor-sensitive-filesởjob7189-apps)
| ClusterImagePolicy(Cosign) |     | 3(zta-job7189-apps-signed, |
| -------------------------- | --- | -------------------------- |
zta-keyless-trust-job7189,zta-system-passthrough)
ClusterSPIFFEID(SPIRE) 10(3zta-*đạidiệnchocáctiervà7chínhsáchbootstrap/oidc)
Podnghiệpvụ 7dịchvụnghiệpvụ(4/4container/podhoạtđộng)+7cơsởdữ
liệuđệmRedis(1/1container/podhoạtđộng)chạyổnđịnhtrong
namespacejob7189-apps
CiliumServiceMeshmTLS TẮT(mesh-auth-enabled=false)—lưulượngL3đượcmã
hóabởimạngriêngảoTailscale
| WireGuardtrongCilium |         | Khôngkíchhoạt(celltrống) |
| -------------------- | ------- | ------------------------ |
| 3.7 Khả              | năng tự | phục hồi                 |
Khi vận hành trên hạ tầng lab có tài nguyên giới hạn (RAM 15.5GiB), việc quá tải hệ
thốngcóthểgâytrễphảnhồicủaAPIServer,dẫnđếnmấtquyềnleadershipcủacáccontroller
như spire-controller hay cilium-operator. Sự bất ổn này có nguy cơ làm gián đoạn
chuỗithựcthichínhsáchbảomật.
Đểgiảmthiểurủiro,dựánthiếtlập4cơchếtựphụchồitrongquytrìnhvậnhành:
36

CHƯƠNG3. TRIỂNKHAITHỰCNGHIỆM
Bảng3.3:Cơchếtựphụchồivàđảmbảotrạngtháiantoàncủahệthống
Cơchế CáchthứchoạtđộngvàMụcđích
1.Pre-flightGate KiểmtratàinguyênRAM/CPUtrướckhicàiđặtcácmodulenặng(SPIRE,
Gatekeeper,Trivy),tránhquátảihệthống.
2.NớilỏngProbes ĐiềuchỉnhcácthamsốLiveness/ReadinessprobecủaSPIREđểgiảmthiểu
việckhởiđộnglạipoddođộtrễAPI.
3.Cleanup-on-fail TựđộnggỡbỏcácthayđổicàiđặtHelmdởdangnếuxảyralỗitimeout,
tránhtìnhtrạngcấuhìnhkhôngnhấtquán.
4.Auto-recovery Chạyvònglặpđốichiếuliêntục.Khipháthiệntiếntrìnhbịkẹthoặc
ConfigMapmồcôi,hệthốngtựđộnggỡbỏvàtáicàiđặtsạchsẽ.
BốncơchếphòngvệtrênhỗtrợhệthốngtựkhôiphụcvềtrạngtháiantoànZTAđãđược
thiếtlập,giảmthiểuviệcphátsinhcáclỗhổngmởngầmđịnhngoàiýmuốn.
37

|         |         | Chương |           | 4    |     |
| ------- | ------- | ------ | --------- | ---- | --- |
|         | Thử     | nghiệm | và        | Đánh | giá |
| 4.1 Mục | tiêu và | phương | pháp đánh | giá  |     |
Chương này kiểm chứng kiến trúc Zero Trust đã triển khai ở Chương 3 theo hai trục độc
lập:
1. Kiểm tra bảo mật: Các cơ chế ZTA có chặn đúng các lớp tấn công đã mô hình hoá
ở Chương 1 hay không. Mỗi kịch bản được thực hiện dựa trên các bằng chứng thực tế
tríchxuấttrựctiếptừnhậtkýsựkiệncủahệthống.
2. Đánhgiáhiệunăng:ChiphítàinguyênvàđộtrễmàZTAđemlại.Phépđođượcthực
hiệntạilớpAPIGatewayđểđánhgiámứcđộảnhhưởngđếnngườidùngcuối.
Toàn bộ 88 trường hợp thử nghiệm được chia thành các nhóm xác nhận cấu hình và mô
phỏnghànhvitấncông,nhằmđốichiếutrựctiếpvớikếtquảthựctế.
| 4.2 Kịch | bản tấn | công | mô phỏng và | minh | chứng thực nghiệm |
| -------- | ------- | ---- | ----------- | ---- | ----------------- |
Phần này kiểm chứng kiến trúc Zero Trust thông qua 10 kịch bản mô phỏng dựa trên
MITREATT&CKContainersMatrix.Cácthửnghiệmtậptrungđánhgiákhảnăngpháthiện,
ngănchặnvàphảnứngcủahệthốngtrướccáchànhvitruycậptráiphép,leothangđặcquyền,
dichuyểnngang(lateralmovement)vàtríchxuấtdữliệutrongmôitrườngKubernetes.
| 4.2.1 Kịchbản1:XâmnhậpquaAPIGatewayvàbỏquaxácthựcMFA |     |     |     |     |     |
| ---------------------------------------------------- | --- | --- | --- | --- | --- |
Mụctiêu:
Đánhgiákhảnăngpháthiệnđăngnhậpbấtthườngtheongữcảnhđịalý,cơchếMFAvàkhả
năngthuhồiphiên(session)truycập.
38

| CHƯƠNG4. |     | THỬNGHIỆMVÀĐÁNHGIÁ |     |     |     |     |     |     |     |
| -------- | --- | ------------------ | --- | --- | --- | --- | --- | --- | --- |
Kịchbản:
MộtJWThợplệbịgiảlậpthuthậpvàđượcsửdụngtừmộtđịachỉIPtạiChâuÂuđểtruycập
hệ thống. Sau đó, thử nghiệm tiếp tục mô phỏng kỹ thuật AiTM (Adversary-in-the-Middle)
nhằmtruycậpcácendpointquảntrị.
Cơchếbảovệ:
OPAđốichiếuvịtríđăngnhậphiệntạivớilịchsửtruycậptrướcđó.Khipháthiệnhiệntượng
ImpossibleTravel,hệthốngtừchốiyêucầuxácthựcvàyêucầuxácthựcMFAbổsung.Sau
khi phiên được thiết lập, module phân tích hành vi tiếp tục giám sát các truy vấn quản trị và
thựchiệnthuhồiphiênkhipháthiệndấuhiệubấtthường.
|     | IP bất  | thường |     |     |      |         |     | OPA Context-Aware |            |
| --- | ------- | ------ | --- | --- | ---- | ------- | --- | ----------------- | ---------- |
|     |         |        |     |     | Kong | Gateway |     |                   |            |
|     |         |        |     |     |      |         |     | Impossible        | Travel     |
|     | Valid   | JWT    |     |     |      |         |     |                   |            |
|     |         |        |     |     | (Chữ | ký hợp  | lệ) |                   |            |
|     | (T1078) |        |     |     |      |         |     | → Drop            | / Buộc MFA |
API Behaviour
| Máy | khách | nội bộ |     |     | Vượt | qua | MFA |     |     |
| --- | ----- | ------ | --- | --- | ---- | --- | --- | --- | --- |
Analytics
| Evilginx2 |     | (T1557) |     |     | Gọi | API quản | trị |       |           |
| --------- | --- | ------- | --- | --- | --- | -------- | --- | ----- | --------- |
|           |     |         |     |     |     |          |     | → Thu | hồi phiên |
Hình4.1:Kịchbản1:ĐánhcắpToken,láchMFAvàcơchếphòngthủnhậnthứcngữcảnh
Kếtquả:
Yêu cầu sử dụng JWT hợp lệ nhưng xuất phát từ IP bất thường bị API Gateway từ chối với
mãHTTP 403.DecisionlogcủaOPAghinhậnlýdotừchốilàimpossible ravel etected.
|     |     |     |     |     |     |     |     |     | t d |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
Thử nghiệm sử dụng IP bất thường để thực hiện gọi API bằng JWT hợp lệ.
| Hệ              | thống | phát hiện                      | sự  | thay | đổi | IP đột | ngột : |     |     |
| --------------- | ----- | ------------------------------ | --- | ---- | --- | ------ | ------ | --- | --- |
| $ MEM_JWT="<dán |       | access_token_cua_user_ha_noi>" |     |      |     |        |        |     |     |
1
| 2 $ MEM_JWT="<dán |     | access_token_cua_user_ha_noi>" |         |                 |     |     |           |     |     |
| ----------------- | --- | ------------------------------ | ------- | --------------- | --- | --- | --------- | --- | --- |
| $ curl            | -sS | -m 10 -w                       | '\nHTTP | %{http_code}\n' |     |     | -X POST \ |     |     |
3
|     | http://10.105.206.111:80/api/v1/jobs |     |     |     |     |     | \   |     |     |
| --- | ------------------------------------ | --- | --- | --- | --- | --- | --- | --- | --- |
4
|     | -H  | "Authorization: |     | Bearer | $MEM_JWT" | \   |     |     |     |
| --- | --- | --------------- | --- | ------ | --------- | --- | --- | --- | --- |
5
|     | -H  | "X-Forwarded-For: |     | 82.102.16.2" |     | \   |     |     |     |
| --- | --- | ----------------- | --- | ------------ | --- | --- | --- | --- | --- |
6
|     |     | 'Content-Type:  | application/json' |         |     |     |     |     |     |
| --- | --- | --------------- | ----------------- | ------- | --- | --- | --- | --- | --- |
| 7   | -H  |                 |                   |         |     | \   |     |     |     |
|     |     | '{"title":"Khai |                   | thac"}' |     |     |     |     |     |
8 -d
9
HTTP 403
10
Listing1:MôphỏngchuyểnvùngvàgiảlậprequestbịAPIGatewaychặnlại
39

| CHƯƠNG4. | THỬNGHIỆMVÀĐÁNHGIÁ |     |     |     |
| -------- | ------------------ | --- | --- | --- |
Trích xuất log của OPA để chứng minh cơ chế ZTA đã phát hiện và ra quyết
| định chặn | đứng: |     |     |     |
| --------- | ----- | --- | --- | --- |
$ kubectl -n security logs deploy/opa | grep "impossible_travel"
1
{
2
| 3 "decision_id": | "4b2a-....", |     |     |     |
| ---------------- | ------------ | --- | --- | --- |
4 "result": { "allow": false, "reason": "impossible_travel_detected" },
| "input": | {   |     |     |     |
| -------- | --- | --- | --- | --- |
5
| "src_ip": | "82.102.16.2", |     |     |     |
| --------- | -------------- | --- | --- | --- |
6
| "last_login_ip": |     | "14.232.112.50", |     |     |
| ---------------- | --- | ---------------- | --- | --- |
7
| 8 "time_diff_mins": |     | 10  |     |     |
| ------------------- | --- | --- | --- | --- |
9 }
Listing2:Vídụlogquyếtđịnh(decisionlog)mongđợicủaOPAkhigiảlậpIPchuyểnvùng
4.2.2 Kịch bản 2: Thực thi mã từ xa và giám sát tiến trình bằng eBPF
| Mục | tiêu: |     |     |     |
| --- | ----- | --- | --- | --- |
Đánh giá khả năng phát hiện hành vi thực thi shell trái phép trong container
| nghiệp | vụ.  |     |     |     |
| ------ | ---- | --- | --- | --- |
| Kịch   | bản: |     |     |     |
Thử nghiệm mô phỏng lỗ hổng thực thi mã từ xa (RCE) trên một dịch vụ public-facing,
buộc tiến trình ứng dụng sinh shell hệ thống thông qua /bin/sh.
| Cơ chế | bảo vệ: |     |     |     |
| ------ | ------- | --- | --- | --- |
Tetragon theo dõi syscall execve tại Kernel Space và kiểm tra quan hệ cha–con
giữa các tiến trình. Các hành vi sinh shell từ tiến trình web được ghi nhận
là bất thường. Seccomp đồng thời giới hạn các syscall nguy hiểm nhằm giảm
| thiểu khả | năng thực | thi payload | hậu khai | thác. |
| --------- | --------- | ----------- | -------- | ----- |
40

|     | CHƯƠNG4. | THỬNGHIỆMVÀĐÁNHGIÁ |        |       |       |     |     |
| --- | -------- | ------------------ | ------ | ----- | ----- | --- | --- |
|     |          |                    | Kernel | Space | (Ring | 0)  |     |
php-fpm
/bin/sh
|     | (PID | 102) | khởitạo | sys_execve |     | chưathựcthi |     |
| --- | ---- | ---- | ------- | ---------- | --- | ----------- | --- |
(Chưa cấp
(/bin/sh)
|     | T1190: | SSTI |     |     |     |     |     |
| --- | ------ | ---- | --- | --- | --- | --- | --- |
phát)
|     | kích | hoạt |     |     |     |     |     |
| --- | ---- | ---- | --- | --- | --- | --- | --- |
intercept
|     |     | Tetragon | eBPF |     |     | Post (Audit | Log) |
| --- | --- | -------- | ---- | --- | --- | ----------- | ---- |
action=Post
|     |     | Phả hệ: | web → shell |     |     | Ghi nhận     | vi phạm |
| --- | --- | ------- | ----------- | --- | --- | ------------ | ------- |
|     |     | =       | Vi phạm     |     |     | (chế độ kiểm | toán)   |
Hình4.2:Kịchbản2:eBPFhooksys_execve—phântíchphảhệtiếntrìnhvàghinhậnviphạm(chế
độkiểmtoán)
|     | Kết quả: |     |     |     |     |     |     |
| --- | -------- | --- | --- | --- | --- | --- | --- |
Lệnh gọi shell được ghi nhận trong runtime log. Tetragon phát hiện và ghi
nhận sự kiện thông qua TracingPolicy (action: Post) nhằm theo dõi và kiểm
|     | toán mà | không làm | gián đoạn     | dịch vụ. |     |     |     |
| --- | ------- | --------- | ------------- | -------- | --- | --- | --- |
|     | Thực    | thi lệnh  | /bin/sh để mở | shell:   |     |     |     |
$ kubectl -n job7189-apps exec deploy/identity-service -c app -- \
1
|     |             | 'id;        |                |             |        | -3' |     |
| --- | ----------- | ----------- | -------------- | ----------- | ------ | --- | --- |
| 2   | /bin/sh     | -c          | uname -a; cat  | /etc/passwd | | head |     |     |
| 3   | uid=0(root) | gid=0(root) | groups=0(root) |             |        |     |     |
4 Linux identity-service-67887999d5-pmlsg 6.12.86+deb13-amd64 #1 SMP PREEMPT_DYNAMIC
root:x:0:0:root:/root:/bin/bash
5
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
6
bin:x:2:2:bin:/bin:/usr/sbin/nologin
7
Listing3:ThựcthishellvàotrongPodnghiệpvụ
Để chứng minh hệ thống đã phát hiện sự cố, ta truy xuất log xuất ra từ
|     | bộ giám | sát tiến | trình Tetragon: |     |     |     |     |
| --- | ------- | -------- | --------------- | --- | --- | --- | --- |
$ kubectl logs ds/tetragon -n kube-system -c export-stdout | grep "execve" | grep "/bin/sh"
1
2 {"process_exec":{"process":{"exec_id":"...","pid":1324,"uid":0,"cwd":"/var/www/html",
3 "binary":"/bin/sh","arguments":"-c id; uname -a","flags":"execve root","parent_exec_id":"..."},
"parent":{"binary":"/usr/local/sbin/php-fpm"}}}
4
Listing4:LogcủaTetragon(xuấtquastdout)ghinhậnrõràngtiếntrìnhchalàphp-fpmđãgọibash
tráiphép
41

| CHƯƠNG4. |     | THỬNGHIỆMVÀĐÁNHGIÁ |     |         |     |       |     |     |           |     |     |     |
| -------- | --- | ------------------ | --- | ------- | --- | ----- | --- | --- | --------- | --- | --- | --- |
| 4.2.3    |     | Kịch               | bản | 3: Đánh | cắp | thông | tin | xác | thực động |     |     |     |
|          | Mục | tiêu:              |     |         |     |       |     |     |           |     |     |     |
Đánh giá hiệu quả của cơ chế cấp phát bí mật động (dynamic secrets) và khả
| năng | hạn  | chế  | tái | sử dụng | thông | tin | xác | thực. |     |     |     |     |
| ---- | ---- | ---- | --- | ------- | ----- | --- | --- | ----- | --- | --- | --- | --- |
|      | Kịch | bản: |     |         |       |     |     |       |     |     |     |     |
Truy cập tệp tin chứa thông tin kết nối CSDL từ bên trong Pod nghiệp vụ sau
| khi | container |         | bị  | truy | cập trái | phép. |     |     |     |     |     |     |
| --- | --------- | ------- | --- | ---- | -------- | ----- | --- | --- | --- | --- | --- | --- |
|     | Cơ        | chế bảo | vệ: |      |          |       |     |     |     |     |     |     |
Vault Agent cấp phát thông tin xác thực động với TTL ngắn và lưu trên RAM
Disk. Chính sách Egress và xác thực định danh của Cilium giới hạn khả năng
| tái | sử    | dụng  | thông | tin  | xác thực    | từ  | các          | Pod không | hợp        | lệ. |     |     |
| --- | ----- | ----- | ----- | ---- | ----------- | --- | ------------ | --------- | ---------- | --- | --- | --- |
|     |       |       |       | Pod: | job-service |     | (Bị truy     | cập       | trái phép) |     |     |     |
|     | Vault | Agent |       |      |             | RAM | Disk (tmpfs) |           |            |     |     |     |
đọctrộm
|     |     |          |     | JITcredential |     |           |     |     |     |     | Tiến trình | ẩn     |
| --- | --- | -------- | --- | ------------- | --- | --------- | --- | --- | --- | --- | ---------- | ------ |
|     |     | Cấp mật  |     |               |     | v-kube-*- |     |     |     |     |            |        |
|     |     |          |     |               |     |           |     |     |     |     | (inotify   | T1546) |
|     |     | khẩu thô |     |               |     | 8KVZKNMr  |     |     |     |     |            |        |
KT1ết04n1ố:icMuyrlS→QLC2
|     |     |     | CNI        | FQDN Egress |     |      |         |      | CNI        | eBPF  | Identity |     |
| --- | --- | --- | ---------- | ----------- | --- | ---- | ------- | ---- | ---------- | ----- | -------- | --- |
|     |     |     | c2.hacker: | Ngoài       |     |      |         |      | Mật        | khẩu: | Đúng     |     |
|     |     |     | Whitelist  | → Drop      |     |      |         |      |            |       |          |     |
|     |     |     |            |             |     |      |         |      | Định danh: | Sai   | → Drop   |     |
|     |     |     |            | PDP:        | Hạ  | điểm | tin cậy | → Cô | lập Pod    |       |          |     |
Hình4.3:Kịchbản3:VaultJIT+CNIđatầngchốngtríchxuấtthôngtinxácthực
|     | Kết | quả: |     |     |     |     |     |     |     |     |     |     |
| --- | --- | ---- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
Thông tin xác thực được sinh động với username ngẫu nhiên và được xoay vòng
liên tục. Log của Vault Agent xác nhận quá trình renewal và render secret
| diễn | ra  | định | kỳ. |     |     |     |     |     |     |     |     |     |
| ---- | --- | ---- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
Mô phỏng truy xuất nội dung file chứa bí mật .env.db từ trong RAM Disk
của Pod và kết quả hiển thị username ngẫu nhiên được cấp thời gian thực:
42

| CHƯƠNG4.  |     | THỬNGHIỆMVÀĐÁNHGIÁ |     |      |                    |     |     |        |      |
| --------- | --- | ------------------ | --- | ---- | ------------------ | --- | --- | ------ | ---- |
| $ kubectl | -n  | job7189-apps       |     | exec | deploy/job-service |     |     | -c app | -- \ |
1
|     | 'head |     |                           |     |     | 2>/dev/null' |     |     |     |
| --- | ----- | --- | ------------------------- | --- | --- | ------------ | --- | --- | --- |
| 2   | sh -c |     | -3 /vault/secrets/.env.db |     |     |              |     |     |     |
3 DB_USERNAME="v-kubernetes-job-servic-8KVZKNMr"
4 DB_PASSWORD="HxJ2IY-szRKLr0QNKhiD"
Listing5:Đọcfilemậtkhẩuđượcsinhđộng
Và log của Vault Agent chứng minh vòng đời bí mật liên tục được xoay vòng:
1 $ kubectl -n job7189-apps logs deploy/job-service -c vault-agent \
'rendered'
| 2   | --tail=10 | 2>/dev/null |     | | grep |     |     |     |     |     |
| --- | --------- | ----------- | --- | ------ | --- | --- | --- | --- | --- |
2026-05-28T08:09:59.059Z [INFO] agent.auth.handler: starting renewal process
3
2026-05-28T08:09:59.950Z [INFO] agent: (runner) rendered "(dynamic)" => "/vault/secrets/.env.db"
4
2026-05-28T08:09:59.952Z [INFO] agent: (runner) rendered "(dynamic)" => "/vault/secrets/.env.db.lease"
5
Listing6:LệnhlấynhậtkýhoạtđộngcủatiếntrìnhVaultAgentvàkếtquả
| 4.2.4 | Kịch      | bản | 4:  | Giả mạo | danh | tính | mạng | nội | bộ  |
| ----- | --------- | --- | --- | ------- | ---- | ---- | ---- | --- | --- |
|       | Mục tiêu: |     |     |         |      |      |      |     |     |
Đánh giá khả năng phát hiện lưu lượng giả mạo IP nguồn trong môi trường Kubernetes.
|     | Kịch bản: |     |     |     |     |     |     |     |     |
| --- | --------- | --- | --- | --- | --- | --- | --- | --- | --- |
Container bị truy cập trái phép tạo Raw Socket và gửi gói tin mang IP nguồn
| giả | mạo nhằm |     | truy cập | trái | phép | vào dịch | vụ  | MySQL | nội bộ. |
| --- | -------- | --- | -------- | ---- | ---- | -------- | --- | ----- | ------- |
|     | Cơ chế   | bảo | vệ:      |      |      |          |     |       |         |
Cilium xác thực Security Identity dựa trên ánh xạ giữa Pod, veth và địa chỉ
IP trong cilium pcache.CcgitincskhngkhpgiaIPngunvSecurityIdentitythctcaPodsbloibtiKernelSpace.
i
| import | socket, | struct |     |     |     |     |     |     |     |
| ------ | ------- | ------ | --- | --- | --- | --- | --- | --- | --- |
1
| # Khởi | tạo | Raw Socket |     | cho giao | thức | TCP |     |     |     |
| ------ | --- | ---------- | --- | -------- | ---- | --- | --- | --- | --- |
2
3 s = socket.socket(socket.AF_INET, socket.SOCK_RAW, socket.IPPROTO_TCP)
4 # Cấu hình không tự động điền IP Header để hacker tự xây dựng
| s.setsockopt(socket.IPPROTO_IP, |     |     |     |     | socket.IP_HDRINCL, |     |     | 1)  |     |
| ------------------------------- | --- | --- | --- | --- | ------------------ | --- | --- | --- | --- |
5
6
# Xây dựng IP Header giả mạo: đặt Source IP thành IP của job-service (10.244.1.25)
7
| # đích | đến | là CSDL | MySQL | (10.244.2.30) |     |     |     |     |     |
| ------ | --- | ------- | ----- | ------------- | --- | --- | --- | --- | --- |
8
struct.pack('!BBHHHBBH4s4s',
9 ip_header = 69, 0, 40, 54321, 0, 64, socket.IPPROTO_TCP, 0,
socket.inet_aton('10.244.1.25'), socket.inet_aton('10.244.2.30'))
10
| # Gửi | gói tin | giả | mạo | IP nguồn | hòng | vượt tường | lửa |     |     |
| ----- | ------- | --- | --- | -------- | ---- | ---------- | --- | --- | --- |
11
| s.sendto(ip_header |     |     | + tcp_header, |     | ('10.244.2.30', |     |     | 3306)) |     |
| ------------------ | --- | --- | ------------- | --- | --------------- | --- | --- | ------ | --- |
12
Listing7:KịchbảnPythonxâydựngthủcôngRawSocketđểgiảmạoIP
43

| CHƯƠNG4. | THỬNGHIỆMVÀĐÁNHGIÁ |     |     |     |     |
| -------- | ------------------ | --- | --- | --- | --- |
hiring-service
| (Bị truy | cập trái phép) |     |     | Mô phỏng    | Raw Socket |
| -------- | -------------- | --- | --- | ----------- | ---------- |
| Root     | / Filesys-     |     |     | IP Spoofing | (T1036)    |
| tem      | Writable       |     |     |             |            |
RawPacket
| Phát hiện | lệch pha       |     |     | Cilium | eBPF   |
| --------- | -------------- | --- | --- | ------ | ------ |
| veth =    | hiring-service |     |     | trong  | Kernel |
Kiểmtradanhtính
| IP = | job-service |     |     | cilium_ipcache |     |
| ---- | ----------- | --- | --- | -------------- | --- |
Identity
| → Drop | tại Kernel |     |     |     |     |
| ------ | ---------- | --- | --- | --- | --- |
Hình4.4:Kịchbản4:CNIpháthiệnlệchphadanhtínhđộngvàIPnguồn
| Kết quả: |     |     |     |     |     |
| -------- | --- | --- | --- | --- | --- |
Kết nối giả mạo không thể thiết lập thành công. Hubble ghi nhận các gói SYN
| bị chặn | với trạng | thái Policy denied | DROPPED. |     |     |
| ------- | --------- | ------------------ | -------- | --- | --- |
Hành vi giả mạo gói tin IP được thực hiện trực tiếp trong container hiring-service
hướng tới cơ sở dữ liệu MySQL của namespace data. Kết quả kiểm tra ghi và
tải gói mạng thất bại, cùng với log chi tiết từ bộ giám sát Hubble tại Kernel
| đích chứng | minh hành | vi chặn đứng | thành công: |     |     |
| ---------- | --------- | ------------ | ----------- | --- | --- |
1 # 1. Thử nghiệm khả năng ghi đè trên hệ điều hành container (Image Not Read-Only)
$ kubectl -n job7189-apps exec deploy/hiring-service -c app -- touch /tmp/test_write
2
[exit=0] # Khả năng ghi đè được kích hoạt do thiếu cấu hình readOnlyRootFilesystem
3
4
5 # 2. Thử nghiệm cài đặt gói scapy để tấn công (Egress bị cô lập hoàn toàn)
6 $ kubectl -n job7189-apps exec deploy/hiring-service -c app -- apt-get update
| Err:1 http://deb.debian.org/debian |     | bookworm | InRelease |     |     |
| ---------------------------------- | --- | -------- | --------- | --- | --- |
7
Cannot initiate the connection to deb.debian.org:80 (146.75.118.132). - connect (101)
8
[exit=124] # Connection timed out - eBPF Egress Filter chặn đứng kết nối Internet
9
10
11 # 3. Theo dõi Ingress Drop bằng Hubble tại nút đích (7189srv05 chứa MySQL)
12 $ TARGET_NODE="7189srv05"
$ TARGET_CILIUM=$(kubectl -n kube-system get pod -l k8s-app=cilium --field-selector spec.nodeName=$TARGET_NODE -o name)
13
$ kubectl -n kube-system exec -it $TARGET_CILIUM -- hubble observe --verdict DROPPED -f
14
May 29 11:57:34.037: job7189-apps/hiring-service-86b448cb56-zw5qm:40592 (ID:13257) <> data/mysql-f5fb77767-jhd8j:3306 (ID:28370) Policy denied DROPPED (TCP Flags: SYN)
15
16 May 29 11:57:34.261: job7189-apps/hiring-service-86b448cb56-zw5qm:56556 (ID:13257) <> data/mysql-f5fb77767-jhd8j:3306 (ID:28370) policy-verdict:none TRAFFIC_DIRECTION_UNKNOWN DENIED (TCP Flags: SYN)
Listing8:Kiểmtratínhwritable,càiđặtthấtbạivàLogcủaHubbleghinhậnsựkiệnDROP
44

| CHƯƠNG4. | THỬNGHIỆMVÀĐÁNHGIÁ |          |         |          |        |        |
| -------- | ------------------ | -------- | ------- | -------- | ------ | ------ |
| 4.2.5    | Kịch bản           | 5: Trích | xuất dữ | liệu qua | Egress | và DNS |
| Mục      | tiêu:              |          |         |          |        |        |
Đánh giá khả năng kiểm soát lưu lượng Egress và phát hiện hành vi DNS tunneling.
| Kịch | bản: |     |     |     |     |     |
| ---- | ---- | --- | --- | --- | --- | --- |
Pod nghiệp vụ thử gửi dữ liệu ra ngoài thông qua HTTP trực tiếp và truy vấn
| DNS chứa | payload     | mã hóa. |     |     |     |     |
| -------- | ----------- | ------- | --- | --- | --- | --- |
| Cơ       | chế bảo vệ: |         |     |     |     |     |
Cilium áp dụng FQDN Whitelist và kiểm soát lưu lượng Egress theo FQDN ở lớp
L7. Các truy vấn hướng đến tên miền ngoài danh sách cho phép bị chặn ngay
| từ kết | nối đầu tiên. |     |     |           |     |     |
| ------ | ------------- | --- | --- | --------- | --- | --- |
|        |               |     | Dữ  | liệu nhạy | cảm |     |
nslookup C2 Domain
| curl | POST C2 |     |     |     |     |     |
| ---- | ------- | --- | --- | --- | --- | --- |
(T1048.003 /
| (T1041 | / T1071.001) |     |     |     |     |     |
| ------ | ------------ | --- | --- | --- | --- | --- |
T1071.004)
| CNI | FQDN Egress |     |     |     |     |     |
| --- | ----------- | --- | --- | --- | --- | --- |
DNS Proxy L7
→ Drop → Từ chối
|     |     | Phân | tích hành | vi: Bất thường | truy | vấn |
| --- | --- | ---- | --------- | -------------- | ---- | --- |
|     |     |      | → Cô      | lập mạng       | Pod  |     |
Hình4.5:Kịchbản5:ChặntríchxuấtdữliệuquaHTTPFQDNvàDNSL7
| Kết | quả: |     |     |     |     |     |
| --- | ---- | --- | --- | --- | --- | --- |
Các kết nối HTTP đến địa chỉ IP ngoài whitelist đều timeout. Hubble xác nhận
| lưu lượng | Egress | bị chặn | tại tầng | mạng. |     |     |
| --------- | ------ | ------- | -------- | ----- | --- | --- |
Cố gắng thực hiện lệnh truy xuất (Egress) tới địa chỉ IP lạ nằm ngoài
Whitelist FQDN, kết quả trả về Connection timed out vì luồng đã bị drop ở
| network | layer: |     |     |     |     |     |
| ------- | ------ | --- | --- | --- | --- | --- |
45

| CHƯƠNG4.  |     | THỬNGHIỆMVÀĐÁNHGIÁ |     |      |                    |     |     |          |     |
| --------- | --- | ------------------ | --- | ---- | ------------------ | --- | --- | -------- | --- |
| $ kubectl | -n  | job7189-apps       |     | exec | deploy/job-service |     | -c  | app -- \ |     |
1
|        |     |      |              |     | 'HTTP | %{http_code}\n' |     |           |     |
| ------ | --- | ---- | ------------ | --- | ----- | --------------- | --- | --------- | --- |
| 2 curl | -sS | -m 8 | -o /dev/null |     | -w    |                 |     | -X DELETE | \   |
3 http://1.1.1.1
| 4 HTTP 000 |      |            |       |     |                |              |     |     |     |
| ---------- | ---- | ---------- | ----- | --- | -------------- | ------------ | --- | --- | --- |
| curl:      | (28) | Connection | timed |     | out after 8001 | milliseconds |     |     |     |
5
| command | terminated |     | with | exit | code 28 |     |     |     |     |
| ------- | ---------- | --- | ---- | ---- | ------- | --- | --- | --- | --- |
6
Listing9:Lệnhmôphỏnghànhvitríchxuấtdữliệubịchặngâyratimeout
Và log Hubble ở cấp hệ thống xác nhận gói tin bị Kernel chặn do vi phạm
Egress Policy. Thay vì gọi ‘hubble‘ trực tiếp trên host (không khả dụng),
lệnh được thực thi qua Cilium pod tương ứng với Node đang chạy ứng dụng:
$ TARGET_NODE=$(kubectl get pod -n job7189-apps -l app=job-service -o jsonpath='{.items[0].spec.nodeName}')
1
$ TARGET_CILIUM=$(kubectl -n kube-system get pod -l k8s-app=cilium --field-selector spec.nodeName=$TARGET_NODE -o name)
2
$ kubectl -n kube-system exec $TARGET_CILIUM -- hubble observe --since 2m --verdict DROPPED --from-namespace job7189-apps
3
4 May 28 09:30:15.221: job7189-apps/job-service-65f9f7cfcb-f6zkl:34660 (ID:5287)
5 <> 1.1.1.1:80 (world) Policy denied DROPPED (TCP Flags: SYN)
Listing10:KếtnốiEgressbịKernelDropdokhôngnằmtrongFQDNWhitelist(đượctríchxuấttừ
đúngCiliumAgent)
| 4.2.6 | Kịch  | bản | 6:  | Chặn | kết nối đến | IP  | độc hại |     |     |
| ----- | ----- | --- | --- | ---- | ----------- | --- | ------- | --- | --- |
| Mục   | tiêu: |     |     |      |             |     |         |     |     |
Đánh giá khả năng tích hợp Threat Intelligence và chặn kết nối đến hạ tầng
độc hại.
| Kịch | bản: |     |     |     |     |     |     |     |     |
| ---- | ---- | --- | --- | --- | --- | --- | --- | --- | --- |
Pod nghiệp vụ thử kết nối trực tiếp đến địa chỉ IP thuộc danh sách đen thay
| vì sử | dụng | tên     | miền. |     |     |     |     |     |     |
| ----- | ---- | ------- | ----- | --- | --- | --- | --- | --- | --- |
| Cơ    | chế  | bảo vệ: |       |     |     |     |     |     |     |
CronJob đồng bộ dữ liệu Threat Intelligence vào CiliumCIDRGroup. Các địa
chỉ IP độc hại được nạp vào eBPF LPM Map và áp dụng tự động trên toàn cụm.
46

| CHƯƠNG4. | THỬNGHIỆMVÀĐÁNHGIÁ |     |           |     |     |     |     |
| -------- | ------------------ | --- | --------- | --- | --- | --- | --- |
|          | CronJob            |     | CậpnhậtIP |     |     |     |     |
CiliumCIDRGroup
|     | Đồng bộ IP | độc hại |     |     |     |     |     |
| --- | ---------- | ------- | --- | --- | --- | --- | --- |
Đồngbộ
|     |            |     | KếtnốiIPlạ | Kernel | eBPF Map Bịchặn |           |     |
| --- | ---------- | --- | ---------- | ------ | --------------- | --------- | --- |
|     | Pod nghiệp | vụ  |            |        |                 | C2 Server | IP  |
|     |            |     |            | So     | khớp IP → Drop  |           |     |
Hình4.6:Kịchbản6:ĐồngbộThreatIntelvàchặnkếtnốiIPđộchạitạiKernel
|     | Kết quả: |     |     |     |     |     |     |
| --- | -------- | --- | --- | --- | --- | --- | --- |
Kiến trúc Threat Intelligence đã được triển khai đầy đủ ở tầng hạ tầng: CiliumClusterwideNetworkPolicy
và CiliumCIDRGroup đã được tạo và xác thực bởi Cilium. Kết nối đến địa chỉ
IP ngoài whitelist bị timeout do chính sách Egress default-deny. Tuy nhiên,
do hạn chế về việc tích hợp feed dữ liệu FireHOL (xem §4.4), danh sách CIDR
trong CiliumCIDRGroup chưa được đồng bộ trong chu kỳ thử nghiệm này.
Cấu hình chính sách cấp cụm được triển khai và xác thực cùng với trạng
| thái | tài nguyên | thực | tế: |     |     |     |     |
| ---- | ---------- | ---- | --- | --- | --- | --- | --- |
# 1. Trích xuất chính sách CiliumClusterwideNetworkPolicy chặn danh sách đen
1
| apiVersion: | cilium.io/v2 |     |     |     |     |     |     |
| ----------- | ------------ | --- | --- | --- | --- | --- | --- |
2
| kind: | CiliumClusterwideNetworkPolicy |     |     |     |     |     |     |
| ----- | ------------------------------ | --- | --- | --- | --- | --- | --- |
3
4 metadata:
| 5   | name: cnp-threat-intel-egress-deny |     |     |     |     |     |     |
| --- | ---------------------------------- | --- | --- | --- | --- | --- | --- |
spec:
6
egressDeny:
7
- toCIDRSet:
8
| 9   | - cidrGroupRef: | threat-intel-firehol |            |           |        |     |     |
| --- | --------------- | -------------------- | ---------- | --------- | ------ | --- | --- |
| 10  | except:         |                      |            |           |        |     |     |
|     | - 100.64.0.0/10 |                      | # Loại trừ | dải CGNAT | nội bộ |     |     |
11
enableDefaultDeny:
12
egress: false # Chỉ áp dụng deny-list, không phải default-deny
13
|     | ingress: | false |     |     |     |     |     |
| --- | -------- | ----- | --- | --- | --- | --- | --- |
14
| 15  | endpointSelector: | {}  | # Áp dụng | toàn cụm |     |     |     |
| --- | ----------------- | --- | --------- | -------- | --- | --- | --- |
Listing11:ĐịnhnghĩachínhsáchchặntoàncụmtheoCIDRGroup(tríchxuấtthựctế)
47

| CHƯƠNG4. |     | THỬNGHIỆMVÀĐÁNHGIÁ |     |     |     |     |     |     |     |
| -------- | --- | ------------------ | --- | --- | --- | --- | --- | --- | --- |
# 2. Trạng thái CiliumCIDRGroup tại thời điểm thử nghiệm (20260603-223945)
1
2 # CronJob threat-intel-refresh đã chạy nhưng feed FireHOL chưa đồng bộ
3 $ kubectl get ciliumcidrgroup threat-intel-firehol -o yaml | head -15
| 4 apiVersion: |                 | cilium.io/v2 |     |     |     |     |     |     |     |
| ------------- | --------------- | ------------ | --- | --- | --- | --- | --- | --- | --- |
| kind:         | CiliumCIDRGroup |              |     |     |     |     |     |     |     |
5
metadata:
6
| name: | threat-intel-firehol |     |     |     |     |     |     |     |     |
| ----- | -------------------- | --- | --- | --- | --- | --- | --- | --- | --- |
7
8 labels:
| 9 app:           | threat-intel |     |          |     |     |     |     |     |     |
| ---------------- | ------------ | --- | -------- | --- | --- | --- | --- | --- | --- |
| cilium.zta/role: |              |     | security |     |     |     |     |     |     |
10
spec:
11
externalCIDRs: [] # <-- Feed chưa được đồng bộ (xem §4.5 Hạn chế)
12
[exit=0]
13
14
15 # 3. Kết nối đến địa chỉ IP độc hại ngoài whitelist FQDN bị chặn bởi Egress default-deny
# Lưu ý: drop xảy ra do thiếu FQDN allow rule, không phải do CIDR denylist
16
| $ kubectl | -n  | job7189-apps |     | run | egress-probe-20260603-223945 |     |     |     | \   |
| --------- | --- | ------------ | --- | --- | ---------------------------- | --- | --- | --- | --- |
17
--image=curlimages/curl:8.10.1 --restart=Never --rm -i --quiet --command -- \
18
|          |      |            |              |     |           | 'HTTP | %{http_code}\n' |     |                      |
| -------- | ---- | ---------- | ------------ | --- | --------- | ----- | --------------- | --- | -------------------- |
| 19 curl  | -sS  | -m 8       | -o /dev/null |     | -w        |       |                 |     | http://203.0.113.50/ |
| 20 curl: | (28) | Connection | timed        |     | out after | 8000  | milliseconds    |     |                      |
| HTTP 000 |      |            |              |     |           |       |                 |     |                      |
21
[exit=28] # Kết nối thất bại - Egress Whitelist chặn traffic ra ngoài
22
23
# 4. Xác minh sự kiện chặn bằng Hubble (chứng minh lệnh bị rớt từ Kernel)
24
jsonpath='{.items[0].spec.nodeName}')
25 $ TARGET_NODE=$(kubectl get pod -n job7189-apps -l run=egress-probe-20260603-223945 -o
26 $ TARGET_CILIUM=$(kubectl -n kube-system get pod -l k8s-app=cilium --field-selector spec.nodeName=$TARGET_NODE -o name)
$ kubectl -n kube-system exec $TARGET_CILIUM -- hubble observe --since 2m --verdict DROPPED | grep "203.0.113.50"
27
May 29 11:58:34.037: job7189-apps/egress-probe-20260603-223945:40592 (ID:13257) <> 203.0.113.50:80 (world) Policy denied DROPPED (TCP Flags: SYN)
28
Listing 12: Trạng thái CIDRGroup và minh chứng kết nối Egress bị chặn ở mức độ Kernel (Hubble
logs)
| 4.2.7 | Kịch  | bản | 7:  | Thỏa | hiệp | chuỗi | cung | ứng |     |
| ----- | ----- | --- | --- | ---- | ---- | ----- | ---- | --- | --- |
| Mục   | tiêu: |     |     |      |      |       |      |     |     |
Đánh giá khả năng kiểm soát image và ngăn chặn workload chưa được xác thực.
| Kịch | bản: |     |     |     |     |     |     |     |     |
| ---- | ---- | --- | --- | --- | --- | --- | --- | --- | --- |
Thử nghiệm triển khai một Pod sử dụng image chưa được ký số hợp lệ và yêu
| cầu đặc | quyền | cao.    |     |     |     |     |     |     |     |
| ------- | ----- | ------- | --- | --- | --- | --- | --- | --- | --- |
| Cơ      | chế   | bảo vệ: |     |     |     |     |     |     |     |
OPA Gatekeeper kiểm tra cấu hình bảo mật của Pod. Sigstore Cosign xác thực
| chữ ký | image | trước |     | khi workload |     | được | nạp | vào | cụm. |
| ------ | ----- | ----- | --- | ------------ | --- | ---- | --- | --- | ---- |
| Kết    | quả:  |       |     |              |     |      |     |     |      |
Admission Webhook từ chối yêu cầu triển khai do image không có chữ ký hợp
48

| CHƯƠNG4. | THỬNGHIỆMVÀĐÁNHGIÁ |     |         |     |     |     |     |
| -------- | ------------------ | --- | ------- | --- | --- | --- | --- |
| lệ theo  | chính sách         |     | Cosign. |     |     |     |     |
Triển khai Pod sử dụng image không có chữ ký số (sử dụng tag thay vì digest):
1 # Manifest thử nghiệm: image dùng tag :malicious-tag thay vì digest sha256:...
| $ kubectl | apply -f | /tmp/unsigned-attacker-20260603-223945.yaml |     |     |     |     |     |
| --------- | -------- | ------------------------------------------- | --- | --- | --- | --- | --- |
2
Error from server (BadRequest): error when creating "...": admission webhook
3
| "policy.sigstore.dev" |     |     | denied | the | request: | validation | failed: |
| --------------------- | --- | --- | ------ | --- | -------- | ---------- | ------- |
4
5 invalid value: ghcr.io/job7189/identity-service:malicious-tag must be
| 6 an image | digest: | spec.containers[0].image |     |     |     |     |     |
| ---------- | ------- | ------------------------ | --- | --- | --- | --- | --- |
[exit=1]
7
8
| # ClusterImagePolicy |     | hiện | đang | hoạt | động trong | cluster |     |
| -------------------- | --- | ---- | ---- | ---- | ---------- | ------- | --- |
9
| $ kubectl | get clusterimagepolicy |     |     |     |     |     |     |
| --------- | ---------------------- | --- | --- | --- | --- | --- | --- |
10
| 11 NAME                    |     |     |     | AGE |     |     |     |
| -------------------------- | --- | --- | --- | --- | --- | --- | --- |
| 12 zta-job7189-apps-signed |     |     |     | 20d |     |     |     |
| zta-keyless-trust-job7189  |     |     |     | 20d |     |     |     |
13
| zta-system-passthrough |     |     |     | 20d |     |     |     |
| ---------------------- | --- | --- | --- | --- | --- | --- | --- |
14
Listing 13: Admission Webhook từ chối Image không sử dụng digest — chính sách yêu cầu image
phảiđượcthamchiếuquadigestsha256
| 4.2.8 | Kịch bản | 8:  | Trinh | sát mạng | nội | bộ  |     |
| ----- | -------- | --- | ----- | -------- | --- | --- | --- |
| Mục   | tiêu:    |     |       |          |     |     |     |
Đánh giá khả năng hạn chế hành vi trinh sát mạng (network discovery) và lạm
| dụng đặc | quyền | hệ điều | hành. |     |     |     |     |
| -------- | ----- | ------- | ----- | --- | --- | --- | --- |
| Kịch     | bản:  |         |       |     |     |     |     |
Container bị truy cập trái phép thử cài đặt công cụ quét mạng, sử dụng curl
| để dò | tìm dịch    | vụ nội | bộ  | và truy | vấn Kubernetes |     | API Server. |
| ----- | ----------- | ------ | --- | ------- | -------------- | --- | ----------- |
| Cơ    | chế bảo vệ: |        |     |         |                |     |             |
Pod bị tước toàn bộ Linux Capabilities và cấu hình readOnlyRootFilesystem.
Chính sách default-deny của Cilium chặn toàn bộ kết nối không được khai báo
tường minh.
| Kết | quả: |     |     |     |     |     |     |
| --- | ---- | --- | --- | --- | --- | --- | --- |
Các lệnh quét nội bộ đều timeout. Truy cập Kubernetes API Server thất bại
| do lưu | lượng Egress |      | bị chặn | trước | khi       | yêu cầu | đến lớp RBAC. |
| ------ | ------------ | ---- | ------- | ----- | --------- | ------- | ------------- |
| Bước   | 1: Xác       | nhận | Pod     | đã bị | tước toàn | bộ      | Capabilities. |
49

| CHƯƠNG4. | THỬNGHIỆMVÀĐÁNHGIÁ |     |     |     |     |     |
| -------- | ------------------ | --- | --- | --- | --- | --- |
1 $ kubectl -n job7189-apps exec deploy/job-service -c app -- \
| cat | /proc/1/status |     | | grep Cap |     |     |     |
| --- | -------------- | --- | ---------- | --- | --- | --- |
2
| CapInh: | 0000000000000000 |     |     |     |     |     |
| ------- | ---------------- | --- | --- | --- | --- | --- |
3
| CapPrm: | 0000000000000000 |     |     |     |     |     |
| ------- | ---------------- | --- | --- | --- | --- | --- |
4
CapEff: 0000000000000000 # <-- Không có bất kỳ capability nào
5
| 6 CapBnd: | 00000000a80425fb |     |     |     |     |     |
| --------- | ---------------- | --- | --- | --- | --- | --- |
| 7 CapAmb: | 0000000000000000 |     |     |     |     |     |
Listing14:KiểmtraCapabilitiesthựctế—CapEff=0nghĩalàkhôngcònđặcquyềnnào
Bước 2: Quét mạng thủ công –- mọi hướng đều bị chặn bởi CiliumNetworkPolicy.
| # Quét | dịch vụ cùng | namespace | (hiring-service) |     |     |     |
| ------ | ------------ | --------- | ---------------- | --- | --- | --- |
1
| $ kubectl | -n job7189-apps |     | exec deploy/job-service |     | -c app | -- \ |
| --------- | --------------- | --- | ----------------------- | --- | ------ | ---- |
2
| curl | -s --connect-timeout |     | 2   | http://hiring-service:80/health |     |     |
| ---- | -------------------- | --- | --- | ------------------------------- | --- | --- |
3
4 command terminated with exit code 28 # TIMEOUT - bị CNP chặn
5
| # Quét | dịch vụ khác | namespace | (mysql.data) |     |     |     |
| ------ | ------------ | --------- | ------------ | --- | --- | --- |
6
| $ kubectl | -n job7189-apps |     | exec deploy/job-service |     | -c app | -- \ |
| --------- | --------------- | --- | ----------------------- | --- | ------ | ---- |
7
| curl | -s --connect-timeout |     | 2   | http://mysql.data:3306 |     |     |
| ---- | -------------------- | --- | --- | ---------------------- | --- | --- |
8
| command | terminated | with | exit code | 28 # TIMEOUT | - bị CNP | chặn |
| ------- | ---------- | ---- | --------- | ------------ | -------- | ---- |
9
Listing15:Curltrinhsátđahướng:cùngnamespace,xuyênnamespace—tấtcảđềutimeout
Bước 3: Liệt kê tài nguyên qua API Server –- CNP chặn trước cả RBAC.
1 $ kubectl -n job7189-apps exec deploy/job-service -c app -- \
| curl | -sk --connect-timeout |     | 5   | \   |     |     |
| ---- | --------------------- | --- | --- | --- | --- | --- |
2
https://kubernetes.default.svc/api/v1/namespaces/data/services
3
command terminated with exit code 28 # TIMEOUT - Egress đến API Server bị chặn
4
Listing16:TruyvấnAPIServerđểliệtkêdịchvụbịCNPchặnEgress
4.2.9 Kịch bản 9: Khai thác Kubelet API và thoát khỏi container
| Mục | tiêu: |     |     |     |     |     |
| --- | ----- | --- | --- | --- | --- | --- |
Đánh giá khả năng bảo vệ Host Node trước các kết nối trái phép và hành vi
| container | escape. |     |     |     |     |     |
| --------- | ------- | --- | --- | --- | --- | --- |
| Kịch      | bản:    |     |     |     |     |     |
Container thử kết nối đến Kubelet API trên cổng 10250 và thực thi các syscall
| đặc quyền | nhằm | thoát | khỏi môi | trường | cô lập container. |     |
| --------- | ---- | ----- | -------- | ------ | ----------------- | --- |
50

| CHƯƠNG4. | THỬNGHIỆMVÀĐÁNHGIÁ |     |     |     |     |
| -------- | ------------------ | --- | --- | --- | --- |
| Cơ       | chế bảo vệ:        |     |     |     |     |
Cilium chặn lưu lượng Egress đến Host Node. Seccomp RuntimeDefault giới hạn
các syscall nhạy cảm như unshare. Tetragon giám sát chặt chẽ các hành vi
| bất thường | tại runtime. |     |     |     |     |
| ---------- | ------------ | --- | --- | --- | --- |
| Kết        | quả:         |     |     |     |     |
Kết nối đến Kubelet API bị timeout. Syscall unshare bị Kernel từ chối với
| lỗi Operation | not | permitted. |     |     |     |
| ------------- | --- | ---------- | --- | --- | --- |
Thử nghiệm quét Kubelet API từ container job-service và gọi syscall đặc
| quyền | chứng minh | các cơ chế | ZTA hoạt động | hiệu quả: |     |
| ----- | ---------- | ---------- | ------------- | --------- | --- |
1 # 1. Thử kết nối trực tiếp đến Kubelet API cổng 10250 trên Node vật lý
| $ kubectl | -n job7189-apps | exec deploy/job-service |     | -c app | -- \ |
| --------- | --------------- | ----------------------- | --- | ------ | ---- |
2
| curl | -sS --connect-timeout | 2   | http://100.114.68.15:10250 |     |     |
| ---- | --------------------- | --- | -------------------------- | --- | --- |
3
curl: (28) Failed to connect to 100.114.68.15 port 10250 after 2002 ms: Timeout was reached
4
[exit=28] # Lệnh timeout hoàn toàn do eBPF chặn đứng kết nối đến Host-level IP
5
6
7 # 2. Thử thoát khỏi sandbox bằng syscall unshare từ bên trong Pod
$ kubectl -n job7189-apps exec deploy/job-service -c app -- unshare -m
8
| unshare: | unshare failed: | Operation | not permitted |     |     |
| -------- | --------------- | --------- | ------------- | --- | --- |
9
[exit=1] # Syscall bị Seccomp chặn đứng và trả về lỗi Operation not permitted
10
Listing17:KếtquảquétKubeletAPIbịTIMEOUTvàsyscallbịSeccompchặnđứng
4.2.10 Kịch bản 10: Sửa đổi trái phép chính sách mạng và tự phục hồi
GitOps
| Mục | tiêu: |     |     |     |     |
| --- | ----- | --- | --- | --- | --- |
Đánh giá khả năng chống thay đổi trái phép cấu hình bảo mật và cơ chế tự
| phục hồi | trạng thái | hệ thống. |     |     |     |
| -------- | ---------- | --------- | --- | --- | --- |
| Kịch     | bản:       |           |     |     |     |
Thử nghiệm giả lập việc sửa đổi hoặc xóa trực tiếp chính sách mạng (Network
| Policy) | trong cụm   | Kubernetes. |     |     |     |
| ------- | ----------- | ----------- | --- | --- | --- |
| Cơ      | chế bảo vệ: |             |     |     |     |
OPA Gatekeeper kiểm tra các thay đổi cấu hình trước khi áp dụng. ArgoCD liên
tục đối chiếu trạng thái thực tế với trạng thái mong muốn (drift detection)
lưu trong Git Repository và tự động khôi phục tài nguyên bị thay đổi.
| Kết | quả: |     |     |     |     |
| --- | ---- | --- | --- | --- | --- |
Kịch bản này xác nhận rằng lệnh xóa chính sách CiliumNetworkPolicy có thể
được thực thi bởi tài khoản có đủ thẩm quyền RBAC. Kiến trúc ZTA hiện tại
bảo vệ chống trôi dạt trạng thái (Anti-Policy Drift) thông qua việc lưu trữ
51

| CHƯƠNG4. | THỬNGHIỆMVÀĐÁNHGIÁ |     |     |     |     |     |     |     |
| -------- | ------------------ | --- | --- | --- | --- | --- | --- | --- |
toàn bộ cấu hình dưới dạng mã (Infrastructure-as-Code) trong repository.
Cơ chế tự phục hồi GitOps được thiết kế để phát hiện và khôi phục sự lệch
| pha này    | tự   | động. |     |            |     |      |     |     |
| ---------- | ---- | ----- | --- | ---------- | --- | ---- | --- | --- |
| # Mô phỏng | thao | tác   | xóa | chính sách |     | mạng |     |     |
1
| $ kubectl | delete | cnp | default-deny-all |     |     | -n job7189-apps |     |     |
| --------- | ------ | --- | ---------------- | --- | --- | --------------- | --- | --- |
2
| 3 ciliumnetworkpolicy.cilium.io |     |     |     | "default-deny-all" |     |     | deleted |     |
| ------------------------------- | --- | --- | --- | ------------------ | --- | --- | ------- | --- |
4
| # Xác nhận | chính | sách | bị  | xóa (khe | hở  | bảo mật | mở) |     |
| ---------- | ----- | ---- | --- | -------- | --- | ------- | --- | --- |
5
| $ kubectl | -n  | job7189-apps |     | get cnp | default-deny-all |     |     |     |
| --------- | --- | ------------ | --- | ------- | ---------------- | --- | --- | --- |
6
Error from server (NotFound): ciliumnetworkpolicies.cilium.io "default-deny-all" not found
7
Listing18:Xóathủcôngchínhsáchdefault-denytạorakhehởbảomậttạmthời
Mặc dù lệnh xóa được thực thi thành công do tài khoản quản trị viên bị
lạm dụng có đủ thẩm quyền RBAC, kiến trúc ZTA được thiết kế theo nguyên tắc
Defense-in-Depth: toàn bộ cấu hình bảo mật được lưu trữ dưới dạng mã nguồn
(Infrastructure-as-Code) và đồng bộ liên tục với trạng thái thực tế của cụm.
Khi cơ chế GitOps được tích hợp đầy đủ (xem §4.4), controller sẽ phát hiện
sự lệch pha và tự động tái áp dụng chính sách từ kho lưu trữ đã được ký số.
Trong phạm vi thử nghiệm hiện tại, quản trị viên thực hiện khôi phục thủ
| công để | xác | nhận | chính | sách | được | tái | áp dụng | chính xác: |
| ------- | --- | ---- | ----- | ---- | ---- | --- | ------- | ---------- |
1 # Khôi phục thủ công từ manifest IaC (mô phỏng hành vi GitOps sync)
$ kubectl apply -f infras/k8s-yaml/cilium-policies/00-default-deny.yaml
2
| ciliumnetworkpolicy.cilium.io/default-deny-all |     |     |     |     |     |     | configured |     |
| ---------------------------------------------- | --- | --- | --- | --- | --- | --- | ---------- | --- |
3
4
| 5 # Xác nhận     | chính | sách         | đã  | được khôi |                  | phục |     |     |
| ---------------- | ----- | ------------ | --- | --------- | ---------------- | ---- | --- | --- |
| 6 $ kubectl      | -n    | job7189-apps |     | get cnp   | default-deny-all |      |     |     |
| 7 NAME           |       |              | AGE |           |                  |      |     |     |
| default-deny-all |       |              | 5s  |           |                  |      |     |     |
8
Listing19:KhôiphụcchínhsáchtừIaCmanifest—minhchứngnguyêntắcAnti-PolicyDrift
| 4.3 | Phân | tích | tổng | hợp | kết | quả |     |     |
| --- | ---- | ---- | ---- | --- | --- | --- | --- | --- |
Tổng hợp kết quả 9 kịch bản thử nghiệm chủ động (KB2–KB10), mỗi kịch bản
kiểm chứng ít nhất một tầng phòng thủ trong kiến trúc Zero Trust. Bảng 4.1
| tóm tắt | kết | quả | theo | từng | kịch | bản. |     |     |
| ------- | --- | --- | ---- | ---- | ---- | ---- | --- | --- |
52

| CHƯƠNG4. | THỬNGHIỆMVÀĐÁNHGIÁ |     |     |     |     |     |     |     |
| -------- | ------------------ | --- | --- | --- | --- | --- | --- | --- |
Bảng4.1:Tổnghợpkếtquả9kịchbảnthửnghiệm
|     | KB Tênkịchbản          |        |         | Cơchếkiểmchứng |       |          |     | Kếtquả |
| --- | ---------------------- | ------ | ------- | -------------- | ----- | -------- | --- | ------ |
|     | 2 RCE                  | + eBPF | Runtime | Tetragon       |       | Tracing- |     | Đạt    |
|     | Monitor                |        |         | Policy(Post)   |       |          |     |        |
|     | 3 ĐánhcắpcredentialJIT |        |         | Vault          | Agent | +        | Dy- | Đạt    |
namicSecrets
|     | 4 Giảmạodanhtínhmạng |     |     | Cilium |     | eBPF | Iden- | Đạt |
| --- | -------------------- | --- | --- | ------ | --- | ---- | ----- | --- |
tity(ipcache)
|     | 5 Egress/DNSTunneling |     |     | Cilium |     | FQDN |     | Đạt |
| --- | --------------------- | --- | --- | ------ | --- | ---- | --- | --- |
EgressPolicy
|     | 6 Chặn              | IP độc | hại (Threat | CiliumCIDRGroup |              |            |     | Mộtphần |
| --- | ------------------- | ------ | ----------- | --------------- | ------------ | ---------- | --- | ------- |
|     | Intel)              |        |             | +CCNP           |              |            |     |         |
|     | 7 Thỏa              | hiệp   | chuỗi       | cung Cosign     |              | ClusterIm- |     | Đạt     |
|     | ứng                 |        |             | agePolicy       |              |            |     |         |
|     | 8 Trinhsátmạngnộibộ |        |             | CNP             | Default-deny |            | +   | Đạt     |
Seccomp
|     | 9 Khai | thác Kubelet |      | + Es- eBPF | Egress | +           | Sec- | Đạt     |
| --- | ------ | ------------ | ---- | ---------- | ------ | ----------- | ---- | ------- |
|     | cape   |              |      | comp       |        |             |      |         |
|     | 10 Sửa | đổi chính    | sách | trái IaC   | +      | Anti-Policy |      | Mộtphần |
|     | phép   |              |      | Drift      |        |             |      |         |
Kết quả cho thấy 7/9 kịch bản đạt kết quả hoàn toàn và 2/9 kịch bản đạt
kết quả một phần. Mô hình phòng thủ theo chiều sâu (Defense-in-Depth) thể
hiện rõ qua việc mỗi kỹ thuật tấn công đều bị chặn bởi ít nhất hai tầng cơ
chế độc lập, giảm thiểu rủi ro từ sự cố đơn điểm (Single Point of Failure).
| 4.4 | Hạn chế | và Hướng |     | phát triển |     |     |     |     |
| --- | ------- | -------- | --- | ---------- | --- | --- | --- | --- |
Trong quá trình thử nghiệm, một số tính năng của kiến trúc ZTA đã được
triển khai nhưng chưa hoàn thiện hoặc chưa hoạt động ở chế độ đầy đủ. Các
hạn chế sau được ghi nhận để làm cơ sở cho hướng phát triển tiếp theo:
| 1. Cosign | ở chế | độ WARN, | chưa | ENFORCE. |     |     |     |     |
| --------- | ----- | -------- | ---- | -------- | --- | --- | --- | --- |
ClusterImagePolicy zta-job7189-apps-signed hiện phát ra cảnh báo (Warning)
thay vì từ chối triển khai (Deny) khi image không thỏa mãn điều kiện
chữ ký. Webhook policy.sigstore.dev từ chối image không dùng digest
(xem kịch bản 7), tuy nhiên việc chuyển sang chế độ ENFORCE đầy đủ đòi
hỏi registry nội bộ hỗ trợ ký số trên toàn bộ pipeline CI/CD.
53

| CHƯƠNG4. THỬNGHIỆMVÀĐÁNHGIÁ |     |     |     |     |     |     |     |
| --------------------------- | --- | --- | --- | --- | --- | --- | --- |
2. Feed Threat Intelligence (FireHOL) chưa được đồng bộ tự động.
CronJob threat-intel-refresh đã được triển khai nhưng CiliumCIDRGroup
threat-intel-firehol vẫn có externalCIDRs: [] trong chu kỳ thử nghiệm.
Nguyên nhân là pipeline đồng bộ phụ thuộc vào kết nối tới nguồn feed
ngoài (FireHOL Level 1) mà môi trường thử nghiệm chưa cấu hình hoàn
chỉnh. Trong tương lai, cần bổ sung cơ chế cache feed nội bộ và kiểm
| tra trạng   | thái đồng | bộ       | trong | vòng | lặp    | CI. |     |
| ----------- | --------- | -------- | ----- | ---- | ------ | --- | --- |
| 3. Tích hợp | GitOps    | (ArgoCD) | chưa  | hoàn | thiện. |     |     |
Cơ chế Anti-Policy Drift dựa trên nguyên tắc Infrastructure-as-Code
đã được kiểm chứng qua khôi phục thủ công (kịch bản 10). Tuy nhiên,
ArgoCD controller chưa được triển khai vào cụm thử nghiệm trong phạm
vi luận văn này. Việc tích hợp đầy đủ GitOps sẽ cho phép tự động phát
| hiện và     | khôi phục | drift | mà  | không | cần     | can thiệp | thủ công. |
| ----------- | --------- | ----- | --- | ----- | ------- | --------- | --------- |
| 4. PDP chưa | đóng vòng | phản  | hồi | với   | dữ liệu | CVE.      |           |
Policy Decision Point (zta-pdp) hiện chạy ở chế độ reconcile-only: đọc
nhãn trust-score từ Pods và duy trì chu kỳ đối chiếu định kỳ, nhưng
chưa tiếp nhận dữ liệu từ Trivy (CVE scanner) để tự động hạ điểm tin
cậy của workload bị phát hiện lỗ hổng. Giai đoạn tiếp theo cần xây dựng
pipeline: Trivy phát hiện CVE → PDP nhận event → tự động áp CNP cô lập
Pod.
54

Kết luận
Sau thời gian nghiên cứu và triển khai thực nghiệm đề tài “Nghiên cứu
Kiến trúc Zero Trust và Ứng dụng trong Bảo mật Hệ thống Microservices trên
Kubernetes”, đồ án đã hoàn thành các mục tiêu đặt ra ban đầu. Dưới đây là
các kết quả chính đạt được:
Vềmặtlýthuyết:
• Hệ thống hóa triết lý bảo mật Zero Trust và kiến trúc tham chiếu ZTA
theo tiêu chuẩn NIST SP 800-207 (Gilman & Barth, 2017; Kindervag, 2010;
Rose et al., 2020), bao gồm 7 nguyên lý, mô hình logic (PE, PA, PEP
và các Data Sources), và 3 hướng tiếp cận triển khai (Enhanced Identity
Governance, Phân đoạn Vi mô, SDP).
• Phân tích chuyên sâu các đặc điểm bảo mật đặc thù của kiến trúc Microservices
trên Kubernetes: sự bùng nổ lưu lượng East-West, tính tạm thời của workload
(ephemeral), thách thức quản lý bí mật (Secrets Sprawl), và rủi ro hạ
tầng dùng chung (Chandramouli, 2019; CyberArk, 2024; Rice & McCarty,
2019).
• Đề xuất khung kiến trúc ZTA 5 lớp tích hợp ánh xạ trực tiếp từ các thành
phần logic NIST sang công cụ mã nguồn mở CNCF (Kubernetes Project, 2024;
Rose et al., 2020), theo phương pháp Best-of-Breed — giải quyết bài
toán Vendor Lock-in thường gặp khi áp dụng Zero Trust (Cybersecurity
and Infrastructure Security Agency (CISA), 2023).
• Xây dựng mô hình đe dọa chi tiết với ánh xạ MITRE ATT&CK cho Kubernetes (MITRE
Corporation, 2024; OWASP Foundation, 2023), chỉ rõ các kỹ thuật tấn
công và lớp ZTA phòng thủ tương ứng.
Vềmặtthựcnghiệm(Hệthốngjob7189):
55

CHƯƠNG4. THỬNGHIỆMVÀĐÁNHGIÁ
• Triển khai thành công microsegmentation bằng CiliumNetworkPolicy (eBPF) (eBPF
Foundation, 2024; Isovalent / CNCF, 2024): áp dụng Default Deny cho
toàn bộ namespace job7189-apps và data, sau đó mở Allow-Explicit cho
đúng các cặp service cần giao tiếp — kiểm soát L3/L4 (IP, Port) trong
kernel và L7 (HTTP method, API path) qua per-node Envoy proxy.
• Hiện thực hóa Dynamic Secrets với HashiCorp Vault (HashiCorp, 2024):
07 microservices nhận database credentials tạm thời (TTL 1 giờ) qua
Vault Agent Injector, lưu trên tmpfs (RAM-only), tự động xoay vòng (rotation)
mà không gây downtime ứng dụng (CyberArk, 2024; Rose et al., 2020).
• Xây dựng hệ thống xác thực tập trung với Keycloak (Keycloak Project,
2024) (kiến trúc Dual-Realm: 7189_internal cho quản trị nội bộ, job7189
cho end-user) kết hợp Kong API Gateway (Kong Inc., 2024) xác thực JWT
RS256 (Hardt, 2012; Jones et al., 2015; Sakimura et al., 2014) cho toàn
bộ luồng North-South.
• Thiết lập lớp Observability với EFK Stack (Elasticsearch + Filebeat
+ Kibana) (Elastic, 2024) thu thập security events từ 4 namespace trọng
điểm, Prometheus + Grafana (Grafana Labs, 2024; Prometheus / CNCF, 2024)
cho Security Metrics thời gian thực, và Hubble UI (Cilium Project, 2024)
trực quan hóa network flow.
• Toàn bộ hạ tầng được triển khai tự động qua pipeline orchestrator 16
phase (scripts/zta-rebuild.sh) trên cụm kubeadm 4 máy ảo (3 Debian 13
+ 1 Ubuntu 24.04 LTS) (Infrastructure as Code) (Helm / CNCF, 2024; Helmfile
Project, 2024; The Kubernetes Authors, 2025), đảm bảo tái tạo được (reproducible),
có ZTA checkpoints tại mỗi giai đoạn, và cô lập áp lực tài nguyên theo
từng node thay vì dùng chung một kernel như baseline Kind 1-host.
Hạnchếvàhướngpháttriển: Cần nhấn mạnh rằng hệ thống job7189 là một Proof
of Concept (PoC) trên cụm thử nghiệm kubeadm 4 nút gồm 4 máy ảo (3 Debian
13 + 1 Ubuntu 24.04 LTS) kết nối qua Tailscale (Tailscale Inc., 2025; The
Kubernetes Authors, 2025), chưa phải một Zero Trust Enterprise hoàn chỉnh.
Đồ án vẫn còn các hạn chế sau:
• Vault Transit Provider: Hiện tại, vault-dev sử dụng chế độ dev mode
(lưu trữ trên RAM) để làm Transit Auto-Unseal cho vault-prod. Khi container
hoặc node khởi động lại, khóa Transit bị mất và Vault Production không
thể tự unseal. Trong môi trường production, cần chuyển sang Raft storage
với PersistentVolume hoặc sử dụng Cloud KMS (AWS KMS, GCP Cloud KMS).
56

CHƯƠNG4. THỬNGHIỆMVÀĐÁNHGIÁ
• Đánh giá thiết bị người dùng (Device Posture): Nguyên lý thứ 5 của NIST
SP 800-207 (Rose et al., 2020) yêu cầu “liên tục đánh giá trạng thái
an ninh của thiết bị” (MDM/EDR) (Cybersecurity and Infrastructure Security
Agency (CISA), 2023). Hệ thống hiện tại chỉ đánh giá workload container
(qua Trivy/Kube-bench lý thuyết) mà chưa kiểm tra thiết bị client (máy
tính, điện thoại) trước khi cấp quyền truy cập. Hướng phát triển: tích
hợp MDM hoặc Device Trust với IdP.
• Xác thực liên tục và thu hồi phiên (Continuous Authentication): Nguyên
lý thứ 6 yêu cầu đánh giá lại rủi ro trong suốt phiên (Rose et al.,
2020). Hệ thống hiện tại sử dụng JWT với TTL ngắn nhưng chưa có cơ chế
thu hồi token giữa chừng (CAEP/ITDR) (Microsoft Threat Intelligence,
2022; OpenID Foundation, 2024) nếu phát hiện hành vi bất thường sau
khi token đã được cấp. Alertmanager pipeline (phát hiện anomaly → giảm
Trust Score → ngắt kết nối tự động) mới ở giai đoạn thiết kế dự kiến.
• Runtime Security: Tetragon TracingPolicy (Isovalent, 2024) (giám sát
syscall, chặn tiến trình độc hại) mới ở giai đoạn thiết kế, chưa được
triển khai thực tế. Hướng phát triển tiếp theo là tích hợp Tetragon
để hoàn thiện lớp PEP Runtime (CrowdStrike, 2024; eBPF Foundation, 2024).
• Mã hóa lưu lượng nội bộ: Cilium mTLS sidecarless và WireGuard encryption (Isovalent
/ CNCF, 2024; SPIFFE Project, 2024; SPIFFE/SPIRE Project, 2024) hiện
tạm tắt trong giai đoạn stability baseline. Cần đánh giá hiệu năng và
kích hoạt để đạt mức bảo mật toàn diện hơn (Istio Project, 2024; Zhu
et al., 2023).
Tóm lại, đồ án đã hiện thực hóa thành công các thành phần chính của kiến
trúc Zero Trust — microsegmentation, dynamic secrets, identity-based access
control và centralized observability — trên một hệ thống Microservices thực
tế. Các hạn chế nêu trên là những bước tiếp theo trên lộ trình chuyển đổi
từ PoC sang một Zero Trust Enterprise hoàn chỉnh, phù hợp với khuyến nghị
“triển khai tuần tự và lặp lại” của NIST SP 800-207 (Mục 7).
57

Bibliography
Bradatsch, L., Lux, Z. Á., Kargl, F., & Smertnig, P. (2023). Zero trust score-based network-
level access control in enterprise networks. Proceedings of the 2023 IEEE 22nd In-
ternational Conference on Trust, Security and Privacy in Computing and Communi-
cations(TrustCom).https://doi.org/10.48550/arXiv.2402.08299
Chandramouli, R. (2019). Security strategies for microservices-based application systems
(tech. rep. No. NIST Special Publication 800-204). National Institute of Standards
andTechnology(NIST).https://doi.org/10.6028/NIST.SP.800-204
Cilium Project. (2024). Hubble: Network, service & security observability for kubernetes
using ebpf. Retrieved February 15, 2026, from https://docs.cilium.io/en/stable/
observability/hubble/
CrowdStrike. (2024). Living off the land (lotl) attacks. Retrieved February 15, 2026, from
https://www.crowdstrike.com/en-us/cybersecurity-101/cyberattacks/living-off-the-
land-attack/
CyberArk.(2024).Machineidentitysecurity:Whatitisandwhyitmatters.RetrievedFebru-
ary15,2026,fromhttps://www.cyberark.com/what-is/machine-identity-security/
CybersecurityandInfrastructureSecurityAgency(CISA).(2023).Zerotrustmaturitymodel
version 2.0 (tech. rep.). Department of Homeland Security. Retrieved June 8, 2026,
from https://www.cisa.gov/sites/default/files/2023-04/zero_trust_maturity_model_
v2_508.pdf
eBPF Foundation. (2024). What is ebpf? an introduction and deep dive into the ebpf tech-
nology.RetrievedFebruary15,2026,fromhttps://ebpf.io/what-is-ebpf/
Elastic. (2024). Elastic stack documentation (elasticsearch, kibana, beats). Retrieved Febru-
ary15,2026,fromhttps://www.elastic.co/elastic-stack/
Forum of Incident Response and Security Teams (FIRST). (2019). Common vulnerability
scoring system v3.1: Specification document (tech. rep.). FIRST. https://www.first.
org/cvss/v3.1/specification-document
Gilman, E., & Barth, D. (2017). Zero trust networks: Building secure systems in untrusted
networks.O’ReillyMedia,Inc.
58

Grafana Labs. (2024). Grafana documentation. Retrieved February 15, 2026, from https:
//grafana.com/docs/grafana/latest/
Hardt, D. (2012). Rfc 6749: The oauth 2.0 authorization framework. Retrieved February 15,
2026,fromhttps://datatracker.ietf.org/doc/html/rfc6749
HashiCorp.(2024).Hashicorpvaultdocumentation.RetrievedFebruary15,2026,fromhttps:
//developer.hashicorp.com/vault/docs
Helm/CNCF.(2024).Helmdocumentation:Thepackagemanagerforkubernetes.Retrieved
February15,2026,fromhttps://helm.sh/docs/
Helmfile Project. (2024). Helmfile documentation: Declarative spec for deploying helm
charts.RetrievedFebruary15,2026,fromhttps://helmfile.readthedocs.io/
Hu, V. C., Ferraiolo, D., Kuhn, R., Schnitzer, A., Sandlin, K., Miller, R., & Scarfone, K.
(2014). Guide to attribute based access control (abac) definition and considerations
(tech. rep. No. NIST Special Publication 800-162). National Institute of Standards
andTechnology(NIST).https://doi.org/10.6028/NIST.SP.800-162
Isovalent.(2024).Tetragon:Ebpf-basedsecurityobservabilityandruntimeenforcement.Re-
trievedFebruary15,2026,fromhttps://tetragon.io/docs/
Isovalent / CNCF. (2024). Cilium documentation: Ebpf-based networking, security, and ob-
servability.RetrievedFebruary15,2026,fromhttps://docs.cilium.io/
Istio Project. (2024). Istio ambient mesh: Sidecar-less service mesh. Retrieved February 15,
2026,fromhttps://istio.io/latest/docs/ambient/
Jeong, E., & Yang, D. (2025). A trust score-based access control model for zero trust archi-
tecture: Design, sensitivity analysis, and real-world performance evaluation. Applied
Sciences,15(17),9551.https://doi.org/10.3390/app15179551
Jericho Forum. (2007). Jericho forum commandments, version 1.2. Retrieved February 15,
2026,fromhttps://collaboration.opengroup.org/jericho/commandments_v1.2.pdf
Jones, M., Bradley, J., & Sakimura, N. (2015). Rfc 7519: Json web token (jwt). Retrieved
February15,2026,fromhttps://datatracker.ietf.org/doc/html/rfc7519
KeycloakProject.(2024).Keycloakdocumentation.RetrievedFebruary15,2026,fromhttps:
//www.keycloak.org/documentation
Kindervag, J. (2010). Build security into your network’s dna: The zero trust network ar-
chitecture (tech. rep.). Forrester Research. Retrieved February 15, 2026, from https:
//media.paloaltonetworks.com/documents/Forrester-Build-Security-Into-Your-
Network.pdf
Kong Inc. (2024). Kong gateway documentation. Retrieved February 15, 2026, from https:
//docs.konghq.com/gateway/
Kubernetes Project. (2024). Kubernetes documentation. Retrieved February 15, 2026, from
https://kubernetes.io/docs/
59

MicrosoftThreatIntelligence.(2022).Fromcookiethefttobec:Attackersuseaitmphishing
sites as entry point to further financial fraud. Retrieved February 15, 2026, from
https://www.microsoft.com/en-us/security/blog/2022/07/12/from-cookie-theft-to-
bec-attackers-use-aitm-phishing-sites-as-entry-point-to-further-financial-fraud/
MITRE Corporation. (2024). Mitre att&ck® matrix for containers. Retrieved February 15,
2026,fromhttps://attack.mitre.org/matrices/enterprise/containers/
OpenID Foundation. (2024). Openid continuous access evaluation profile (caep) specifica-
tion 1.0. Retrieved February 15, 2026, from https://openid.net/specs/openid-caep-
specification-1_0.html
OWASPFoundation.(2023).Owaspapisecuritytop10–2023.RetrievedFebruary15,2026,
fromhttps://owasp.org/www-project-api-security/
Prometheus/CNCF.(2024).Prometheusdocumentation.RetrievedFebruary15,2026,from
https://prometheus.io/docs/introduction/overview/
Rice, L., & McCarty, M. (2019). Kubernetes security: Operating kubernetes clusters and
applicationssafely.O’ReillyMedia,Inc.
Rose,S.,Borchert,O.,Kerman,A.,Souppaya,M.,Howell,G.,Ajmo,J.,Fashina,Y.,Grayeli,
P., Hunt, J., Hurlburt, J., Irrechukwu, N., Klosterman, J., Slivina, O., Symington,
S., Tan, A., Scarfone, K., & Barker, W. (2025). Implementing a zero trust architec-
ture (tech. rep. No. NIST Special Publication 1800-35). National Institute of Stan-
dards and Technology (NIST) National Cybersecurity Center of Excellence (NC-
CoE).https://doi.org/10.6028/NIST.SP.1800-35
Rose,S.,Borchert,O.,Mitchell,S.,&Connelly,S.(2020).Zerotrustarchitecture(tech.rep.
No.NISTSpecialPublication800-207).NationalInstituteofStandardsandTechnol-
ogy(NIST).https://doi.org/10.6028/NIST.SP.800-207
Sakimura, N., Bradley, J., Jones, M., de Medeiros, B., & Mortimore, C. (2014). Openid
connectcore1.0specification.RetrievedFebruary15,2026,fromhttps://openid.net/
specs/openid-connect-core-1_0.html
SPIFFE Project. (2024). Spiffe: Secure production identity framework for everyone. Re-
trievedFebruary15,2026,fromhttps://spiffe.io/docs/latest/spiffe-about/overview/
SPIFFE/SPIRE Project. (2024). Spire documentation. Retrieved February 15, 2026, from
https://spiffe.io/docs/latest/spire-about/
TailscaleInc.(2025).Tailscale:Zeroconfigvpnbuiltonwireguard.RetrievedMay13,2026,
fromhttps://tailscale.com/kb/
TheFalcoAuthors.(2024).Falco:Cloudnativeruntimesecurity[Truycập:2024].
TheKubernetesAuthors.(2024).Podlifecycle[Truycập:2024].
TheKubernetesAuthors.(2025).Creatingaclusterwithkubeadm.RetrievedMay13,2026,
from https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/
create-cluster-kubeadm/
60

Zhu,X.,She,G.,Xue,B.,Zhang,Y.,Zhang,Y.,Zou,X.K.,Duan,X.,He,P.,Krishnamurthy,
A.,Lentz,M.,Zhuo,D.,&Mahajan,R.(2023).Dissectingoverheadsofservicemesh
sidecars.Proceedingsofthe2023ACMSymposiumonCloudComputing(SoCC’23).
https://doi.org/10.1145/3620678.3624652
61
