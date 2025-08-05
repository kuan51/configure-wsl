#Requires -Modules Pester

# Simple test to isolate Pester 3.x issues
Describe "Simple Test" {
    It "Should pass basic test" {
        $true | Should Be $true
    }
    
    It "Should test module import" {
        $ModulePath = Join-Path $PSScriptRoot "..\src\ConfigureWSL.psd1"
        Import-Module $ModulePath -Force
        $module = Get-Module ConfigureWSL
        $module | Should Not BeNullOrEmpty
        Remove-Module ConfigureWSL -Force -ErrorAction SilentlyContinue
    }
}