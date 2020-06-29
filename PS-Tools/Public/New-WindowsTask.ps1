function New-WindowsTask {

    [cmdletbinding(SupportsShouldProcess)]

    param
    (
        [switch]
        $OutputXML,

        [string]
        $TaskFolder,


        [Parameter(
            Mandatory = $true
        )]
        [string]
        $TaskName,
        

        [Parameter(
            Mandatory = $true
        )]
        [string]
        $TaskDescription,


        [Parameter(
            Mandatory = $true,
            HelpMessage = 'Provide the start time for the task in the form of a [datetime] object.'
        )]
        [datetime]
        $StartTime,


        [Parameter(
            Mandatory = $true
        )]
        [ValidateScript(
            {
                Test-Path -Path $_ -PathType Leaf
            }
        )]
        [string]
        $Executable,


        [string]
        $Arguments,


        [Parameter(
            ParameterSetName = 'Daily',
            Mandatory = $true
        )]
        [switch]
        $Daily,


        [Parameter(
            ParameterSetName = 'Daily',
            Mandatory = $true
        )]
        [ValidateRange(1, 1440)]
        [int]
        $RepetitionInterval,


        [Parameter(
            ParameterSetName = 'Daily',
            Mandatory = $true
        )]
        [ValidateRange(1, 1440)]
        [int]
        $RepetitionDuration,


        [Parameter(
            ParameterSetName = 'Weekly',
            Mandatory = $true
        )]
        [switch]
        $Weekly,


        [Parameter(
            ParameterSetName = 'Monthly',
            Mandatory = $true
        )]
        [switch]
        $Monthly,


        [Parameter(
            ParameterSetName = 'MonthlyDoW',
            Mandatory = $true
        )]
        [switch]
        $MonthlyDoW,


        [Parameter(
            ParameterSetName = 'Daily'
        )]
        [ValidateRange(1, 365)]
        [int]
        $DaysInterval = 1,


        [Parameter(
            ParameterSetName = 'Weekly',
            Mandatory = $true
        )]
        [Parameter(
            ParameterSetName = 'MonthlyDoW',
            Mandatory = $true
        )]
        [ValidateScript(
            {
                foreach ($Day in $_) {
                    if ($Day -notin @('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat')) {
                        $true
                    }
                    else {
                        throw "`nNot a valid day of the week`nPlease use: Sun, Mon, Tue, Wed, Thu, Fri, Sat"
                    }    
                }
            }
        )]
        [string[]]
        $DaysOfWeek,


        [Parameter(
            ParameterSetName = 'Weekly'
        )]
        [ValidateRange(1, 52)]
        [string[]]
        $WeeksInterval = 1,


        [Parameter(
            ParameterSetName = 'Monthly',
            Mandatory = $true
        )]
        [Parameter(
            ParameterSetName = 'MonthlyDoW',
            Mandatory = $true
        )]
        [ValidateScript(
            {
                foreach ($Month in $_) {
                    if ($Month -in @('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec')) {
                        $true
                    }
                    else {
                        throw "`nNot a valid day of the Month`nPlease use: 'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'"
                    }    
                }
            }
        )]
        [object[]]
        $MonthsOfYear,
  

        [Parameter(
            ParameterSetName = 'Monthly'
        )]
        [ValidateScript(
            {
                $DaysInMonth =
                @{
                    Jan = 31
                    Feb = 29
                    Mar = 31
                    Apr = 30
                    May = 31
                    Jun = 30
                    Jul = 31
                    Aug = 31
                    Sep = 30
                    Oct = 31
                    Nov = 30
                    Dec = 31
                }
                foreach ($Month in $MonthsOfYear) {
                    foreach ($Day in $_) {
                        if ($Day -in @(1..$DaysInMonth[$Month]) -or $Day -ceq 'Last') {
                            $true
                        }
                        else {
                            throw "`nNot a valid day of the Month`n$Month can use 1 to $($DaysInMonth[$Month]) or 'Last'"
                        }    
                    }
                }
            }
        )]
        [object[]]
        $DaysOfMonth,


        [Parameter(
            ParameterSetName = 'Monthly'
        )]
        [ValidateRange(1, 4)]
        [int[]]
        $WeeksOfMonth,


        [Parameter(
            ParameterSetName = 'Monthly'
        )]
        [switch]
        $LastWeekOfMonth
    
    )


    function Convert-DaysOfWeek {
        param
        (
            [string[]]$DaysOfWeek
        )

        $Sum = 0

        foreach ($Day in $DaysOfWeek) {
            # Use the position of the value in the array to determine the decimal value of the day
            # https://docs.microsoft.com/en-us/windows/win32/taskschd/weeklytrigger-daysofweek
            $Sum += [math]::pow(2, $C_DaysOfWeek.IndexOf($Day))
        }

        return $Sum
    }

    function Convert-DaysOfMonth {
        param
        (
            [string[]]$DaysOfMonth
        )

        $Sum = 0

        foreach ($Day in $DaysOfMonth) {
            # Use the position of the value in the array to determine the decimal value of the day
            # https://docs.microsoft.com/en-us/windows/win32/taskschd/monthlytrigger-daysofmonth
            if ($Day -is [string] -and $Day -ne 'Last') { $Day = [int]$Day }
            $Sum += [math]::pow(2, $C_DaysOfMonth.IndexOf($Day))
        }

        return $Sum
    }

    function Convert-MonthsOfYear {
        param
        (
            [string[]]$MonthsOfYear
        )

        $Sum = 0

        foreach ($Month in $MonthsOfYear) {
            # Use the position of the value in the array to determine the decimal value of the month
            # https://docs.microsoft.com/en-us/windows/win32/taskschd/monthlytrigger-monthsofyear
            $Sum += [math]::pow(2, $C_MonthsOfYear.IndexOf($Month))
        }

        return $Sum
    }

    function Convert-WeeksOfMonth {
        param
        (
            [int[]]$WeeksOfMonth
        )

        $Sum = 0

        foreach ($Week in $WeeksOfMonth) {
            # Use the decimal value for week of the month to find the bitwise mask value
            # Subtract one when using as the exponent, because math
            # https://docs.microsoft.com/en-us/windows/win32/taskschd/monthlydowtrigger-weeksofmonth
            $Sum += [math]::pow(2, $Week - 1)
        }

        return $Sum
    }

    function Convert-Duration {
        param
        (
            [int]$Time
        )

        $Hours = [math]::floor($Time / 60)
        $Minutes = $Time % 60

        return "PT${Hours}H${Minutes}M"
    }

    function Convert-Time {
        param
        (
            [datetime]$DateTime
        )

        Get-Date $DateTime
    }


    $C_DaysOfWeek = @('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat')
    $C_DaysOfMonth = @(1..31) + 'Last'
    $C_MonthsOfYear = @('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec')

    # Define the Task Service object
    $Service = New-Object -ComObject Schedule.Service
    $Service.Connect()


    # Set the folder for the task to use
    if ($TaskFolder -in $PSBoundParameters) {
        try {
            $Folder = $Service.GetFolder($TaskFolder)
        }
        catch {
            Format-Error -e $_ -Message 'Unable to locate the requested task folder'
        }
    }
    else {
        $Folder = $Service.GetFolder('\')
    }


    # Create the Task Definition object
    # Flags param is currently unsupported and must be 0
    $TaskDefinition = $Service.NewTask(0)


    # Set Task registration information
    $TaskDefinition.RegistrationInfo.Description = $TaskDescription


    # Set Task Principal
    # Set RunLevel = 1 for highest privileges
    $TaskDefinition.Principal.LogonType = 5
    $TaskDefinition.Principal.DisplayName = 'SYSTEM'
    $TaskDefinition.Principal.UserId = 'S-1-5-18'
    $TaskDefinition.Principal.RunLevel = 1


    # Set Task Settings
    # MultipleInstances = 2 means no new instance will be started
    $TaskDefinition.Settings.Enabled = $true
    $TaskDefinition.Settings.Hidden = $false
    $TaskDefinition.Settings.MultipleInstances = 2


    # Set Task Triggers
    # $TaskTrigger is the integer that represents the trigger type (see docs)
    if ($Daily) {
        $Trigger = $TaskDefinition.Triggers.Create(2)
        $Trigger.DaysInterval = $DaysInterval
        $Trigger.Repetition.Duration = Convert-Duration $RepetitionDuration
        $Trigger.Repetition.Interval = Convert-Duration $RepetitionInterval
    }
    if ($Weekly) {
        $Trigger = $TaskDefinition.Triggers.Create(3)
        $Trigger.WeeksInterval = $WeeksInterval
        $Trigger.DaysOfWeek = Convert-DaysOfWeek -DaysOfWeek $DaysOfWeek
    }
    if ($Monthly) {
        $Trigger = $TaskDefinition.Triggers.Create(4)
        $Trigger.DaysOfMonth = Convert-DaysOfMonth -DaysOfMonth $DaysOfMonth
        $Trigger.MonthsOfYear = Convert-MonthsOfYear -MonthsOfYear $MonthsOfYear
    }
    if ($MonthlyDoW) {
        $Trigger = $TaskDefinition.Triggers.Create(5)
        $Trigger.DaysOfWeek = Convert-DaysOfWeek -DaysOfWeek $DaysOfWeek
        $Trigger.MonthsOfYear = Convert-MonthsOfYear -MonthsOfYear $MonthsOfYear
        if ($LastWeekOfMonth) {
            $Trigger.RunOnLastWeekOfMonth = $true
        }
        else {
            $Trigger.WeeksOfMonth = Convert-WeeksOfMonth -WeeksOfMonth $WeeksOfMonth
        }
    }
    $Trigger.Id = 'MainTrigger'
    $Trigger.Enabled = $true
    # Set start time using the required format
    # The [0] converts the result from a single element string array to a string
    # https://docs.microsoft.com/en-us/windows/win32/taskschd/trigger-startboundary
    # https://docs.microsoft.com/en-us/dotnet/standard/base-types/standard-date-and-time-format-strings?view=netframework-4.8
    $Trigger.StartBoundary = $StartTime.GetDateTimeFormats('O')[0]



    # Set the action
    # The 0 creates an executable action
    $Action = $TaskDefinition.Actions.Create(0)
    $Action.Path = $Executable
    if ($PSBoundParameters['Arguments']) {
        $Action.Arguments = $Arguments
    }
    

    # Create Task!
    # (path, definition, flags, userid, password, logontype)
    # Flags: 6 - Create or Update Task
    # LogonType: 5 - Service Account (System,Service,Network)
    # https://docs.microsoft.com/en-us/windows/win32/taskschd/taskfolder-registertaskdefinition
    if ($PSCmdlet.ShouldProcess("Scheduled Task $TaskName", 'Create')) {
            if ($OutputXML) {
                Write-InformationPlus $TaskDefinition.XmlText
            }
            else {
                $Folder.RegisterTaskDefinition($TaskName, $TaskDefinition, 6, $null, $null, 5)
            }
        }
    
    }
