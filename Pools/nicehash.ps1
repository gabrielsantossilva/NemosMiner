if (!(IsLoaded(".\Includes\include.ps1"))) { . .\Includes\include.ps1; RegisterLoaded(".\Includes\include.ps1") }
try {
    $Request = Invoke-WebRequest "https://api2.nicehash.com/main/api/v2/public/simplemultialgo/info/" -TimeoutSec 15 -UseBasicParsing -Headers @{"Cache-Control" = "no-cache" } | ConvertFrom-Json 
    $RequestAlgodetails = Invoke-WebRequest "https://api2.nicehash.com/main/api/v2/mining/algorithms/" -TimeoutSec 15 -UseBasicParsing -Headers @{"Cache-Control" = "no-cache" } | ConvertFrom-Json 
    $Request.miningAlgorithms | ForEach-Object { $Algo = $_.Algorithm ; $_ | Add-Member -force @{algodetails = $RequestAlgodetails.miningAlgorithms | Where-Object { $_.Algorithm -eq $Algo } } }
}
catch { return }
if (-not $Request) { return }
$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ConfName = if ($Config.PoolsConfig.$Name -ne $Null) { $Name }else { "default" }
$PoolConf = $Config.PoolsConfig.$ConfName
$Request.miningAlgorithms | Where-Object { $_.paying -gt 0 } <# algos paying 0 fail stratum #> | ForEach-Object {
    $Algo = $_.Algorithm
    $NiceHash_Port = $_.algodetails.port
    $NiceHash_Algorithm = Get-Algorithm $_.Algorithm
    $NiceHash_Coin = ""
    $DivisorMultiplier = 1000000000
    $Divisor = $DivisorMultiplier * [Double]$_.Algodetails.marketFactor
    $Divisor = 100000000
    $Stat = Set-Stat -Name "$($Name)_$($NiceHash_Algorithm)_Profit" -Value ([Double]$_.paying / $Divisor)
    $Locations = "eu", "usa", "jp"
    $Locations | ForEach-Object {
        $NiceHash_Location = $_
        switch ($NiceHash_Location) {
            "eu" { $Location = "EU" }
            "usa" { $Location = "US" }
            "jp" { $Location = "JP" }
        }
        $NiceHash_Host = "$($Algo).$($NiceHash_Location)-new.nicehash.com"
        if ($PoolConf.Wallet) {
            [PSCustomObject]@{
                Algorithm     = $NiceHash_Algorithm
                Info          = $NiceHash_Coin
                Price         = $Stat.Live * $PoolConf.PricePenaltyFactor
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = $NiceHash_Host
                Port          = $NiceHash_Port
                User          = "$($PoolConf.Wallet).$($PoolConf.WorkerName.Replace('ID=',''))"
                Pass          = "x"
                Location      = $Location
                SSL           = $false
            }
            [PSCustomObject]@{
                Algorithm     = $NiceHash_Algorithm
                Info          = $NiceHash_Coin
                Price         = $Stat.Live * $PoolConf.PricePenaltyFactor
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+ssl"
                Host          = $NiceHash_Host
                Port          = $NiceHash_Port
                User          = "$($PoolConf.Wallet).$($PoolConf.WorkerName.Replace('ID=',''))"
                Pass          = "x"
                Location      = $Location
                SSL           = $true
            }
        }
    }
}
