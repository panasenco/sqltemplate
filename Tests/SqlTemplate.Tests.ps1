 if (Get-Module -Name SqlTemplate) {Remove-Module -Name SqlTemplate};
Import-Module .\SqlTemplate.psd1

Describe "Use-Sql" {
    Context "invoked with just the path" {
        It "doesn't invoke EPS on files without .eps1.sql extension" {
            Use-Sql -Path ".\Tests\Files\NotTemplate.sql" | Should -Not -Match "^\s*$"
        }
        It "can process trivial template files" {
            Use-Sql -Path ".\Tests\Files\Trivial.eps1.sql" | Should -Match "^SELECT 'abc' AS abc\s*$"
        }
        It "can process simple template files" {
            @{Columns=@('a','b','c')} | Use-Sql -Path ".\Tests\Files\Simple.eps1.sql" |
                Should -Match "^SELECT 'a' AS a, 'b' AS b, 'c' AS c, 4 AS x\s*$"
        }
    }
    Context "invoked with standard templates" {
        It "processes ToDate template OK for Oracle" {
            @{Server='ORA'; StringExpression="'01/02/2003'"; Format='MM/DD/YYYY'} | Use-Sql -Template 'ToDate' |
                Should -Match "^TO_DATE\('01/02/2003', 'MM/DD/YYYY'\)\s*$"
        }
        It "processes ToDate template OK for SQL Server" {
            @{Server='SS13'; StringExpression="'01/02/2003'"; Format='MM/DD/YYYY'} | Use-Sql -Template 'ToDate' |
                Should -Match "^CONVERT\(DATETIME, '01/02/2003', 101\)\s*$"
        }
        It "processes ToInt template OK for Oracle" {
            @{Server='ORA'; StringExpression="'42'"} | Use-Sql -Template 'ToInt' |
                Should -Match "^TO_NUMBER\('42'\)\s*$"
        }
        It "processes ToInt template OK for SQL Server" {
            @{Server='SS13'; StringExpression="'42'"} | Use-Sql -Template 'ToInt' |
                Should -Match "^CAST\('42' AS int\)\s*$"
        }
        It "processes ToIntYYYYMMDD template OK for Oracle" {
            @{Server='ORA'; Date="'01/02/2003'"} | Use-Sql -Template 'ToIntYYYYMMDD' |
                Should -Match "^TO_NUMBER\(CONVERT\(char(8), '01/02/2003', 112\)\)s*$"
        }
        It "processes ToIntYYYYMMDD template OK for SQL Server" {
            @{Server='SS13'; Date="'01/02/2003'"} | Use-Sql -Template 'ToIntYYYYMMDD' |
                Should -Match "^CAST\(CONVERT\(char(8), '01/02/2003', 112\) AS int\)\s*$"
        }
    }
    Context "invoked with wrappers" {
        It "works with the inline wrapper" {
            Use-Sql -Path ".\Tests\Files\Trivial.eps1.sql" -Wrappers 'Inline' |
                Should -Match "^\(\s*SELECT 'abc' AS abc\s*\) Trivial"
        }
        It "works with nested wrappers" {
            $Body = @{Server='SS13'; Prefix='dbo.'} |
                Use-Sql -Path ".\Tests\Files\Trivial.eps1.sql" -Wrappers @('View','Procedure')
            $Body | Should -Match "^CREATE OR ALTER PROCEDURE dbo.Trivial AS\s*BEGIN"
            $Body | Should -Match "CREATE OR ALTER VIEW dbo.Trivial AS"
            $Body | Should -Match "SELECT"
        }
    }
}
