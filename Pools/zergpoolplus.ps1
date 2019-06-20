if (!(IsLoaded(".\Includes\include.ps1"))) {. .\Includes\include.ps1;RegisterLoaded(".\Includes\include.ps1")}

Try {
    $Request = get-content ((split-path -parent (get-item $script:MyInvocation.MyCommand.Path).Directory) + "\BrainPlus\zergpoolplus\zergpoolplus.json") | ConvertFrom-Json
}
catch { return }

if (-not $Request) {return}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$HostSuffix = ".mine.zergpool.com"
$PriceField = "Plus_Price"
# $PriceField = "actual_last24h"
# $PriceField = "estimate_current"
$DivisorMultiplier = 1000000
 
$Location = "US"

# Placed here for Perf (Disk reads)
	$ConfName = if ($Config.PoolsConfig.$Name -ne $Null){$Name}else{"default"}
    $PoolConf = $Config.PoolsConfig.$ConfName

$Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    $PoolHost = "$($_)$($HostSuffix)"
    $PoolPort = $Request.$_.port
    $PoolAlgorithm = Get-Algorithm $Request.$_.name
    
    $Divisor = $DivisorMultiplier * [Double]$Request.$_.mbtc_mh_factor

	$Stat = Set-Stat -Name "$($Name)_$($PoolAlgorithm)_Profit" -Value ([Double]$Request.$_.$PriceField / $Divisor * (1 - ($Request.$_.fees / 100)))

	$PwdCurr = if ($PoolConf.PwdCurrency) {$PoolConf.PwdCurrency}else {$Config.Passwordcurrency}
    $WorkerName = If ($PoolConf.WorkerName -like "ID=*") {$PoolConf.WorkerName} else {"ID=$($PoolConf.WorkerName)"}
    
    $PoolPassword = If ( ! $Config.PartyWhenAvailable ) {"$($WorkerName),c=$($PwdCurr)"} else { "$($WorkerName),c=$($PwdCurr),m=party.NPlusMiner" }
    $PoolPassword = If ( $Config.ExcludeSoloCoinsOnBrainPlus -and $Request.$_.MC ) {
        If ($Config.UseTopCoinOnBrainPlus) {
            $MC = $Request.$_.MC.Split("/")[0]
        } else {
            $MC = $Request.$_.MC
        }
        "$($PoolPassword),mc=$($MC)"
    } else {
        $PoolPassword
    }
	
    if ($PoolConf.Wallet) {
        [PSCustomObject]@{
            Algorithm     = $PoolAlgorithm
            Info          = $MC
            Price         = $Stat.Live*$PoolConf.PricePenaltyFactor #*$SoloPenalty
            StablePrice   = $Stat.Week
            MarginOfError = $Stat.Week_Fluctuation
            Protocol      = "stratum+tcp"
            Host          = $PoolHost
            Port          = $PoolPort
            User          = $PoolConf.Wallet
		    Pass          = $PoolPassword
            Location      = $Location
            SSL           = $false
        }
    }
}
