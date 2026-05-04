## Detection

What should have caught this?

### GuardDuty Finding

Enable GuardDuty and it automatically raises:

`UnauthorizedAccess:IAMUser/InstanceCredentialExfiltration.OutsideAWS`

This fires when EC2 instance credentials are used from an IP address outside AWS — exactly what happens when an attacker steals credentials via SSRF and uses them from their own machine.

```bash
# Enable GuardDuty
aws guardduty create-detector --enable --region us-east-1
```

### CloudTrail — What to Look For

In CloudTrail, look for:

*   `GetCredentials` calls from unexpected source IPs
    
*   `ListBucket` / `GetObject` events from the EC2 role originating from a non-AWS IP
    
*   Any API call using the instance role from outside the EC2's known IP
    

### Athena Query on CloudTrail Logs

```sql
SELECT
  eventTime,
  userIdentity.arn,
  sourceIPAddress,
  eventName,
  requestParameters
FROM cloudtrail_logs
WHERE
  eventSource = 's3.amazonaws.com'
  AND eventName IN ('GetObject', 'ListBucket', 'ListAllMyBuckets')
  AND userIdentity.sessionContext.sessionIssuer.userName = 'yourname-autopsy-role'
  AND sourceIPAddress NOT LIKE '%.amazonaws.com'
ORDER BY eventTime DESC
LIMIT 50;
```

Any S3 access from a non-AWS IP using an EC2 role is a **critical red flag**.

* * *
