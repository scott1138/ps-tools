function Send-Email {

    [CmdletBinding(SupportsShouldProcess=$True)]

    param (
        [Parameter(ParameterSetName='',Mandatory=$true)]
        [string[]] $To,

        [string[]] $Cc = $null,

        [string[]] $Bcc = $null,

        [Parameter(Mandatory=$true)]
        [string] $From,

        [Parameter(Mandatory=$true)]
        [string] $Subject,

        # Check TemplateName Against Valid Templates
        [ValidateScript({$_ -in (Get-EmailTemplate).Name})]
        [string] $TemplateName,

        [string] $Body,

        [switch] $IsHtml,

        [hashtable] $TokenReplacement,

        [hashtable] $Images,

        [array] $Attachments,

        [pscredential] $ExchangeCredential,

        [switch] $ExchangeOnline
    )

    if ($ExchangeOnline) {
        $SmtpServer = 'smtp.office365.com'
        $SmtpPort = 587
        $TLS = $true
    }
    else {
        $SmtpServer = 'internal.mail.server'
        $SmtpPort = 25
        $TLS = $false
    }

    $Email       = New-Object Net.Mail.MailMessage
    $SmtpClient  = New-Object Net.Mail.SmtpClient($SmtpServer,$SmtpPort)

    $SmtpClient.Credentials = $ExchangeCredential

    $To  | Foreach-Object {$Email.To.Add($_)}
    if (-not [string]::IsNullOrEmpty($Cc)) { $Cc | Foreach-Object {$Email.Cc.Add($_)} }
    if (-not [string]::IsNullOrEmpty($Bcc)) { $Bcc | Foreach-Object {$Email.Bcc.Add($_)} }

    $Email.From       = $From
    $Email.Subject    = $Subject


    if (-Not [string]::IsNullOrEmpty($TemplateName)) {
        $TemplatePath = "$PSScriptRoot\EmailTemplates\$TemplateName"
        $Body = Get-Content -Path "$TemplatePath\template.txt"
        $IsHtml = $true
        if (Test-Path -Path "$TemplatePath\images.ps1") {
            . "$TemplatePath\images.ps1"
        }
    }

    # Token replacement in text
    foreach ($Key in $TokenReplacement.Keys) {
        $Body = $Body.Replace($Key,$TokenReplacement[$Key])
    }

    $Email.Body       = $Body
    $Email.IsBodyHtml = $IsHtml

    # Add inline images
    foreach ($Key in $Images.Keys) {
        $i = New-Object Net.Mail.Attachment($Images[$Key])
        $i.ContentDisposition.Inline = $True
        $i.ContentDisposition.DispositionType = "Inline"
        $i.ContentType.MediaType = "image/jpg"
        $i.ContentId = $Key
        $Email.Attachments.Add($i)
    }

    # Add standard attachments
    foreach ($Attachment in $Attachments) {
        $a = New-Object Net.Mail.Attachment($Attachment)
        $Email.Attachments.Add($a)
    }

    # Send Email
    try {
        if ($PSCmdlet.ShouldProcess($To -join ',', "Sending an email notification")) {
            $SmtpClient.Send($Email)
        }
    }
    catch {
        Throw $_
    }

    # Cleanup
    $Email.Dispose()
    $SmtpClient.Dispose()

    <#
    .SYNOPSIS
        This function sends an email with a variety of options, including using HTML with inline attachments.

    .PARAMETER To
        Recipient email address(es) as a string or an array of strings:
        'user1@example.com'
        @('user1@example.com','user2@example.com')

    .PARAMETER Cc
        Carbon copy recepient email address(es) as a string or an array of strings:
        'user1@example.com'
        @('user1@example.com','user2@example.com')

    .PARAMETER Bcc
        Blind carbon copy recepient email address(es) as a string or an array of strings:
        'user1@example.com'
        @('user1@example.com','user2@example.com')

    .PARAMETER From
        Sender email addresses as a string:
        'user1@example.com'

    .PARAMETER Subject
        Subject of the email as a string.

    .PARAMETER TemplateName
        Name of a preformatted email template included with the module.
        Available templates can be discovered using Get-EmailTemplate.

    .PARAMETER Body
        Body of the email as a string.  Can be plain text or html

    .PARAMETER IsHTML
        Switch parameter that sets the message to interpret the body as html

    .PARAMETER TokenReplacement
        This parameter is a hashtable of tokens and their replacement value.  The standard template tokens are #WORD#.
        Token replacement hashtable might look something like:
            $TokenReplacement = @{
                '#FIRSTNAME#' = 'Luke'
                '#USERNAME#'  = 'luke.skywalker@rebels.org'
            }

    .PARAMETER Images
        This parameter is a hashtable of CIDs and image paths. The CID is referenced in the HTML for in line images.
        The images hashtable might look something like:
            $Images = @{
                banner  = 'c:\pics\pic1.jpg'
                picture = 'c:\pics\pic2.jpg'
            }

        Refenced in HTML:
            <body>
                <img src="cid:banner"> </br>
                <p>Important Message!</p>
                <img src="cid:picture"> </br>
            </body>

    .PARAMETER Attachments
        This parameter is the full path location of files to attach as a string or an array of strings.

    .PARAMETER ExchangeCredential
        This parameter provides a username and password as a pscredential object used to connect to Exchange Online.
        The credentials must be to a valid mailbox with at least an E1 license.

    .PARAMETER ExchangeOnline
        This is a switch parameter that indicates the connection information for Exchange Online should be used.


    .EXAMPLE
        PS> Send-Email -To 'some.user@example.com' -From 'another.user@example.com' -Subject 'Relevant Subject' -Body 'Important Message'

        Simple mail sent as a notification

    .EXAMPLE
        PS> $Body = Get-Content -Path email_html.txt
        PS> $Images = @{banner='banner.jpg';layout='layout.jpg'}
        PS> Send-Email -To 'some.user@example.com' -From 'another.user@example.com' -Subject 'Relevant Subject' -Body $Body -IsHtml -Images $Images

        Sends a html email with inline images.

    .EXAMPLE
        PS> $Body = Get-Content -Path email_html.txt
        PS> Send-Email -To 'some.user@example.com' -From 'another.user@example.com' -Subject 'Relevant Subject' -Body $Body -IsHtml -Attachments 'c:\files\information.doc'

        Send a html email with an attachment

    .EXAMPLE
        PS> $Body = Get-Content -Path email_html.txt
        PS> Send-Email -To 'some.user@example.com' -From 'another.user@example.com' -Subject 'Relevant Subject' -Body $Body -IsHtml -Attachments @('c:\files\information.doc','c:\files\information.doc')

        Send a html email with multiple attachments

    .EXAMPLE
        PS> Send-Email -To 'some.user@example.com' -From 'another.user@example.com' -Subject 'Relevant Subject' -TemplateName 'New_Password' -TokenReplacement @{'#FIRSTNAME#'='Mike';'#ONETIMESECRET#'='LONGGUID'}

        Send an email using the New_Password template with values for embedded tokens.
    .LINK
        PS-Tools Project URL
        https://github.com/scott1138/ps-tools

    #>

}
