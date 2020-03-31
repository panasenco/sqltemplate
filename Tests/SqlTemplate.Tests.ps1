 if (Get-Module -Name SqlTemplate) {Remove-Module -Name SqlTemplate};
Import-Module .\SqlTemplate.psd1

Describe "Use-Sql" {
    Context "invoked with just the template" {
        It "processes simple inline templates OK" {
            @{Server='SS13'} | Use-Sql -Template '<%= $Server %>' | Should -Match "^SS13\s*$"
        }
    }
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
