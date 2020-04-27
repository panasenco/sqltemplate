 if (Get-Module -Name SqlTemplate) {Remove-Module -Name SqlTemplate};
Import-Module .\SqlTemplate.psd1

Describe "Invoke-SqlTemplate" {
    Context "invoked without wrappers" {
        It "doesn't invoke EPS on files without .eps1.sql extension" {
            Invoke-SqlTemplate -Path ".\Tests\Files\NotTemplate.sql" | Should -Not -Match "^\s*$"
        }
        It "processes trivial template files and trims trailing whitespace" {
            Invoke-SqlTemplate -Path ".\Tests\Files\Trivial.eps1.sql" | Should -Be "SELECT 'abc' AS abc"
        }
        It -Skip "can handle null binding" {
            $Null | Invoke-SqlTemplate -Path ".\Tests\Files\Trivial.eps1.sql" |
                Should -Match "^SELECT 'abc' AS abc\s*$"
        }
        It "can process simple template files" {
            @{Columns=@('a','b','c')} | Invoke-SqlTemplate -Path ".\Tests\Files\Simple.eps1.sql" |
                Should -Match "^SELECT 'a' AS a, 'b' AS b, 'c' AS c, 4 AS x\s*$"
        }
        It "trims trailing whitespace in string templates" {
            Invoke-SqlTemplate -Template "SELECT 'a'  `r  `n  `r`n `t " | Should -Be "SELECT 'a'"
        }
    }
    Context "invoked with cross-platform helper wrappers" {
        It "processes Concatenate wrapper OK for Oracle" {
            @{Server='ORA'} | Invoke-SqlTemplate -Template "'a'`r`n'b'`r`n'c'" -Wrapper 'Concatenate' |
                Should -Be "'a' || 'b' || 'c'"
        }
        It "processes Concatenate wrapper OK for SQL Server" {
            @{Server='SS13'} | Invoke-SqlTemplate -Template "'a'
'b'
'c'" -Wrapper 'Concatenate' |
                Should -Be "'a' + 'b' + 'c'"
        }
        It "trims trailing whitespace in wrappers" {
            @{Server='ORA'} | Invoke-SqlTemplate -Template "'a'`r`n'b'`r`n'c'`r`n`r`n" -Wrapper 'Concatenate' |
                Should -Be "'a' || 'b' || 'c'"
        }
        It "processes DateDiff wrapper OK for Oracle" {
            @{Server='ORA'} | Invoke-SqlTemplate -Template "S`r`nE" -Wrapper 'DateDiff' | Should -Be "E - S"
        }
        It "processes DateDiff wrapper OK for SQL Server" {
            @{Server='SS13'} | Invoke-SqlTemplate -Template "S
E" -Wrapper 'DateDiff' |
                Should -Be "DATEDIFF(day, S, E)"
        }
        It "processes DateToString wrapper OK for Oracle" {
            @{Server='ORA'; ToFormat='YYYYMMDD'} | Invoke-SqlTemplate -Template "'01/02/2003'" -Wrapper 'DateToString' |
                Should -Be "TO_CHAR('01/02/2003', 'YYYYMMDD')"
        }
        It "processes DateToString wrapper OK for SQL Server" {
            @{Server='SS13'; ToFormat='YYYYMMDD'} |
                Invoke-SqlTemplate -Template "'01/02/2003'" -Wrapper 'DateToString' |
                Should -Be "CONVERT(char(8), '01/02/2003', 112)"
            @{Server='SS13'; ToFormat='MM/DD/YYYY'} |
                Invoke-SqlTemplate -Template "'01/02/2003'" -Wrapper 'DateToString' |
                Should -Be "CONVERT(char(10), '01/02/2003', 101)"
        }
        It "processes QuotedId wrapper OK for Oracle" {
            @{Server='ORA'} | Invoke-SqlTemplate -Template "abcd" -Wrapper 'QuotedId' |
                Should -Be '"abcd"'
        }
        It "processes QuotedId wrapper OK for SQL Server" {
            @{Server='SS13'} | Invoke-SqlTemplate -Template "abcd" -Wrapper 'QuotedId' |
                Should -Be '[abcd]'
        }
        It "processes Sanitize wrapper OK for Oracle" {
            @{Server='ORA'} | Invoke-SqlTemplate -Template "'abcd'" -Wrapper 'Sanitize' |
                Should -Be "REGEXP_REPLACE('abcd', '[[:cntrl:]]')"
        }
        It "processes Sanitize wrapper OK for SQL Server" {
            @{Server='SS13'} | Invoke-SqlTemplate -Template "'abcd'" -Wrapper 'Sanitize' |
                Should -Be "STRING_ESCAPE('abcd', 'json')"
        }
        It "processes SelectSingle wrapper OK for Oracle" {
            @{Server='ORA'} | Invoke-SqlTemplate -Template "'abcd' AS x" -Wrapper 'SelectSingle' |
                Should -Be "SELECT 'abcd' AS x FROM dual"
        }
        It "processes SelectSingle wrapper OK for SQL Server" {
            @{Server='SS13'} | Invoke-SqlTemplate -Template "'abcd' AS x" -Wrapper 'SelectSingle' |
                Should -Be "SELECT 'abcd' AS x"
        }
        It "processes Aggregate wrapper OK for Oracle" {
            @{Server='ORA'; Separator='; '; Order='y DESC'} |
                Invoke-SqlTemplate -Template "y" -Wrapper 'Aggregate' |
                Should -Be "LISTAGG(y, '; ') WITHIN GROUP (ORDER BY y DESC)"
        }
        It "processes Aggregate wrapper OK for SQL Server 13" {
            $Body = @{Server='SS13'; Separator='; '; Order='y DESC'; GroupField='t.y'; Filter='y > 3'} |
                Invoke-SqlTemplate -Template "y" -Wrapper 'Aggregate'
            $Body | Should -Match "N'; ' \+ y"
            $Body | Should -Match "WHERE t.y = t2.y\s*AND y > 3"
            $Body | Should -Match "ORDER BY y DESC"
            $Body | Should -Match "1, 2, N''"
        }
        It "processes StringLength wrapper OK for Oracle" {
            @{Server='ORA'} | Invoke-SqlTemplate -Template "'abcd'" -Wrapper 'StringLength' |
                Should -Be "LENGTH('abcd')"
        }
        It "processes StringLength wrapper OK for SQL Server" {
            @{Server='SS13'} | Invoke-SqlTemplate -Template "'abcd'" -Wrapper 'StringLength' |
                Should -Be "LEN('abcd')"
        }
        It "processes Substring wrapper OK for Oracle" {
            @{Server='ORA'; Position=3; Length=5} |
                Invoke-SqlTemplate -Template "'abcdefghijk'" -Wrapper 'Substring' |
                Should -Be "SUBSTR('abcdefghijk', 3, 5)"
        }
        It "processes Substring wrapper OK for SQL Server" {
            @{Server='SS13'; Position=3; Length=5} |
                Invoke-SqlTemplate -Template "'abcdefghijk'" -Wrapper 'Substring' |
                Should -Be "SUBSTRING('abcdefghijk', 3, 5)"
        }
        It "defaults position to 1 in Substring wraper" {
            @{Server='SS13'; Length=5} | Invoke-SqlTemplate -Template "'abcdefghijk'" -Wrapper 'Substring' |
                Should -Be "SUBSTRING('abcdefghijk', 1, 5)"
        }
        It "processes SubstringIndex wrapper OK for Oracle" {
            @{Server='ORA'; Substring="'def'"} |
                Invoke-SqlTemplate -Template "'abcdefghijk'" -Wrapper 'SubstringIndex' |
                Should -Be "INSTR('abcdefghijk', 'def')"
        }
        It "processes SubstringIndex wrapper OK for SQL Server" {
            @{Server='SS13'; Substring="'def'"} |
                Invoke-SqlTemplate -Template "'abcdefghijk'" -Wrapper 'SubstringIndex' |
                Should -Be "CHARINDEX('def', 'abcdefghijk')"
        }
        It "processes SystemDate wrapper OK for Oracle" {
            @{Server='ORA'} | Invoke-SqlTemplate -Wrapper 'SystemDate' | Should -Be "SYSDATE"
        }
        It "processes SystemDate wrapper OK for SQL Server" {
            @{Server='SS13'} | Invoke-SqlTemplate -Wrapper 'SystemDate' | Should -Be "CAST(SYSDATETIME() AS date)"
        }
        It "processes StringToDate wrapper OK for Oracle" {
            @{Server='ORA'; FromFormat='MM/DD/YYYY'} |
                Invoke-SqlTemplate -Template "'01/02/2003'" -Wrapper 'StringToDate' |
                Should -Be "TO_DATE('01/02/2003', 'MM/DD/YYYY')"
        }
        It "processes StringToDate wrapper OK for SQL Server" {
            @{Server='SS13'; FromFormat='MM/DD/YYYY'} |
                Invoke-SqlTemplate -Template "'01/02/2003'" -Wrapper 'StringToDate' |
                Should -Be "CONVERT(DATETIME, '01/02/2003', 101)"
        }
        It "processes string to date to string in a different format" {
            @{Server='SS13'; FromFormat='MM/DD/YYYY'; ToFormat='YYYYMMDD'} |
                Invoke-SqlTemplate -Template "'01/02/2003'" -Wrapper 'StringToDate','DateToString' |
                Should -Be "CONVERT(char(8), CONVERT(DATETIME, '01/02/2003', 101), 112)"
        }
        It "processes StringToInt wrapper OK for Oracle" {
            @{Server='ORA'} | Invoke-SqlTemplate -Template "'42'" -Wrapper 'StringToInt' |
                Should -Be "TO_NUMBER('42')"
        }
        It "processes StringToInt wrapper OK for SQL Server" {
            @{Server='SS13'} | Invoke-SqlTemplate -Template "'42'" -Wrapper 'StringToInt' |
                Should -Be "CAST('42' AS int)"
        }
        It "processes DateToString + StringToInt combination OK for Oracle" {
            @{Server='ORA'; ToFormat='YYYYMMDD'} |
                Invoke-SqlTemplate -Template "'01/02/2003'" -Wrapper 'DateToString','StringToInt' |
                Should -Be "TO_NUMBER(TO_CHAR('01/02/2003', 'YYYYMMDD'))"
        }
        It "processes DateToString + StringToInt combination OK for SQL Server" {
            @{Server='SS13'; ToFormat='YYYYMMDD'} |
                Invoke-SqlTemplate -Template "'01/02/2003'" -Wrapper 'DateToString','StringToInt' |
                Should -Be "CAST(CONVERT(char(8), '01/02/2003', 112) AS int)"
        }
        It "scrubs values from aggregated strings OK" {
            @{Separator='; '; RemoveList=@('abcd','efg')} |
                Invoke-SqlTemplate -Template 'string' -Wrapper 'RemoveAggregated' | Should -Be (
                "REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(string, '; abcd', ''), '; efg', ''), " + 
                "'abcd; ', ''), 'efg; ', ''), 'abcd', ''), 'efg', '')")
        }
    }
    Context "invoked with feature wrappers" {
        It "processes the CTE wrapper OK" {
            Invoke-SqlTemplate -Path ".\Tests\Files\Trivial.eps1.sql" -Wrapper 'CTE' |
                Should -Be "Trivial AS (`r`n  SELECT 'abc' AS abc`r`n)"
        }
        It "processes the inline wrapper OK" {
            Invoke-SqlTemplate -Path ".\Tests\Files\Trivial.eps1.sql" -Wrapper 'Inline' |
                Should -Be "(`r`n  SELECT 'abc' AS abc`r`n) Trivial"
        }
        It "processes simple JUnit wrapper OK for SQL Server" {
            $Body = @{Server='SS13'} | Invoke-SqlTemplate -Path ".\Tests\Files\Trivial.eps1.sql" -Wrapper 'JUnit'
            $Body | Should -Match "xml"
            $Body | Should -Match "AS test_result\s+UNION ALL"
        }
        It "processes JUnit wrapper with CTES OK for SQL Server" {
            $Body = @{Server='SS13'} | Invoke-SqlTemplate -Path ".\Tests\Files\Complex.eps1.sql" -Wrapper 'JUnit'
            $Body | Should -Match "\)`r`n\s*SELECT '<\?xml"
        }
        It "processes individual JUnit wrapper OK for SQL Server" {
            @{Server='SS13'; TestName='my test'} | Invoke-SqlTemplate -Template 'x=1' -Wrapper 'JUnitTest' |
                Should -Be ("'<testcase name=`"my test`">' + CASE WHEN x=1 THEN '' ELSE '<failure/>' END + " +
                "'</testcase>' AS test_result")
        }
        It "works with nested wrappers" {
            $Body = @{Server='SS13'; ProcedurePrefix='dbo.'; ViewPrefix='dbo.' } |
                Invoke-SqlTemplate -Path ".\Tests\Files\Trivial.eps1.sql" -Wrapper @('View','Procedure')
            $Body | Should -Match "^CREATE OR ALTER PROCEDURE dbo.Trivial AS\s*BEGIN"
            $Body | Should -Match "CREATE OR ALTER VIEW dbo.Trivial AS"
            $Body | Should -Match "SELECT"
        }
        It "gives correct basenames to single-extension files" {
            Invoke-SqlTemplate -Path ".\Tests\Files\NotTemplate.sql" -Wrapper 'Inline' | Should -match 'NotTemplate$'
        }
        It "gives correct basenames to multi-extension files" {
            Invoke-SqlTemplate -Path ".\Tests\Files\Trivial.eps1.sql" -Wrapper 'Inline' | Should -match 'Trivial$'
        }
        It "materializes correctly in SQL Server" {
            $Body = @{Server='SS13'; TablePrefix='dbo.'} | Invoke-SqlTemplate -Path ".\Tests\Files\Complex.eps1.sql" `
                -Wrapper 'Materialize'
            $Body | Should -Match 'DROP TABLE dbo\.Complex[^\r\n]*\r\n\s*WITH'
            $Body | Should -Match 'INTO dbo\.Complex\r\n\s*FROM NonRootFruits'
            $Body | Should -Not -Match 'INTO [^\r\n]*\r\n\s*INTO'
        }
        It "inserts DROP TABLEs, INTOs, and variable declarations as expected in nested materialization" {
            $Body = @{Server='SS13'; TablePrefix='dbo.'} | Invoke-SqlTemplate -Path `
                ".\Tests\Files\MaterializeSelect.eps1.sql" ` -Wrapper 'Materialize'
            $Body | Should -Match 'DROP TABLE dbo\.Complex[^\r\n]*\r\n\s*WITH'
            $Body | Should -Match 'INTO dbo\.Complex\r\n\s*FROM NonRootFruits'
            $Body | Should -Not -Match 'INTO [^\r\n]*\r\n\s*INTO'
            $Body | Should -Not -Match 'UNION ALL\r\nIF OBJECT_ID'
        }
        It "conditionally executes correctly in SQL Server" {
            $Body = @{Server='SS13'} | Invoke-SqlTemplate -Template 'dbo.sp_stuff' -Wrapper 'ExecuteIfExists'
            $Body | Should -Be "IF OBJECT_ID('dbo.sp_stuff', 'P') IS NOT NULL`r`n  EXEC dbo.sp_stuff;"
        }
    }
}
