workspace "Job7189 Architecture" "Sơ đồ kiến trúc dữ liệu hệ thống Job7189" {

    model {
        # External Systems
        identityProvider = softwareSystem "Identity Provider" "Hệ thống quản lý danh tính và xác thực tập trung." "Keycloak"
        objectStorage = softwareSystem "Object Storage" "Hệ thống lưu trữ object cho tệp tin CV và ảnh." "External"

        jobSystem = softwareSystem "Job7189 System" "Hệ thống tuyển dụng trực tuyến." {

            group "Identity Cluster" {
                identitySvc = container "Identity Service" "Quản lý hồ sơ người dùng." "Laravel" "Microservice"
                idDb = container "Identity DB" "Lưu tt tài khoản." "MySQL" "Database"
                idCache = container "Identity Cache" "Bộ nhớ đệm profile." "Redis" "Cache"
            }

            group "Workspace Cluster" {
                workspaceSvc = container "Workspace Service" "Quản lý tổ chức và quyền." "Laravel" "Microservice"
                wsDb = container "Workspace DB" "Lưu tt công ty." "MySQL" "Database"
                wsCache = container "Workspace Cache" "Bộ nhớ đệm quyền hạn." "Redis" "Cache"
            }

            group "Job Cluster" {
                jobSvc = container "Job Service" "Quản lý tin tuyển dụng." "Laravel" "Microservice"
                jobDb = container "Job DB" "Lưu nội dung tin." "MySQL" "Database"
                jobCache = container "Job Cache" "Bộ nhớ đệm tin đăng." "Redis" "Cache"
            }

            group "Hiring Cluster" {
                hiringSvc = container "Hiring Service" "Quản lý quy trình ATS." "Laravel" "Microservice"
                hrDb = container "Hiring DB" "Lưu đơn ứng tuyển." "MySQL" "Database"
                hrCache = container "Hiring Cache" "Bộ nhớ đệm quy trình." "Redis" "Cache"
            }

            group "Candidate Cluster" {
                candidateSvc = container "Candidate Service" "Quản lý hồ sơ ứng viên." "Laravel" "Microservice"
                canDb = container "Candidate DB" "Lưu tt ứng viên." "MySQL" "Database"
                canCache = container "Candidate Cache" "Bộ nhớ đệm hồ sơ." "Redis" "Cache"
            }

            group "Communication Cluster" {
                commSvc = container "Communication Service" "Xử lý kênh chat & email." "Laravel" "Microservice"
                comDb = container "Communication DB" "Lưu nhật ký trao đổi." "MySQL" "Database"
                comCache = container "Communication Cache" "Bộ nhớ đệm liên hệ." "Redis" "Cache"
            }

            storageSvc = container "Storage Service" "Quản lý quyền truy cập tệp tin (S3)." "Laravel" "Microservice"
        }

        # Relationships (Chỉ nối trong cụm để giảm lag và đúng kiến trúc)
        identitySvc -> idDb "Đọc/Ghi"
        identitySvc -> idCache "Cache"
        
        workspaceSvc -> wsDb "Đọc/Ghi"
        workspaceSvc -> wsCache "Cache"
        
        jobSvc -> jobDb "Đọc/Ghi"
        jobSvc -> jobCache "Cache"
        
        hiringSvc -> hrDb "Đọc/Ghi"
        hiringSvc -> hrCache "Cache"
        
        candidateSvc -> canDb "Đọc/Ghi"
        candidateSvc -> canCache "Cache"
        
        commSvc -> comDb "Đọc/Ghi"
        commSvc -> comCache "Cache"

        storageSvc -> objectStorage "Quản lý tệp"
        identitySvc -> identityProvider "Đồng bộ"
    }

    views {
        container jobSystem "ViewDuLieu" "Sơ đồ Container: Kiến trúc lưu trữ và bộ nhớ đệm" {
            include *
            # autoLayout tb
        }

        styles {
            element "Element" {
                metadata true
                description true
                fontSize 42
            }
            element "Microservice" {
                shape Hexagon
                background #2f9d66
                color #ffffff
            }
            element "Database" {
                shape Cylinder
                background #85bbf0
                color #000000
            }
            element "Cache" {
                shape Cylinder
                background #ff5555
                color #ffffff
            }
            element "External" {
                background #999999
                color #ffffff
            }
            element "Keycloak" {
                background #999999
                color #ffffff
            }
            relationship "Relationship" {
                thickness 8
                color #000000
                fontSize 45
            }
        }
    }
}