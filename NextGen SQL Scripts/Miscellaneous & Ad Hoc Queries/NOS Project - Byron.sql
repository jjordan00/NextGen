--/****** Script for SelectTopNRows command from SSMS  ******/
--SELECT TOP 1000 [Name]
--      ,[DOB]
--      ,[Status]
--  FROM [NGDemo].[dbo].[aggcmd]

----
--Update aggcmd Set name = replace(name, '%,', '')


--UPDATE aggcmd
--SET name = LEFT(name, CHARINDEX(',', name) - 1)
--WHERE CHARINDEX(',', name) > 0
----alter table aggcmd alter column DOB nvarchar(100)

--delete from aggcmd where status is null

select pat.practice_id, p.last_name, ac.name,p.date_of_birth, ac.dob, ac.status, psm.description, ps.modified_by, um.last_name --ps.modify_timestamp
from person p 
INNER JOIN aggcmd ac on ac.dob=p.date_of_birth
INNER JOIN patient pat on p.person_id = pat.person_id 
INNER JOIN patient_status ps on ps.person_id = pat.person_id and pat.practice_id = ps.practice_id
INNER JOIN patient_status_mstr psm on ps.patient_status_id = psm.patient_status_id
INNER JOIN user_mstr um on um.user_Id = ps.modified_by
where ac.name = p.last_name and p.date_of_birth = ac.dob and description = 'Active' and pat.practice_id = '0001' and (ac.status = 'inactive' or ac.status like '%exp%' or ac.status like '%d/c%' or ac.status like '%dis%' or ac.status like '%dec%')
and ps.modified_by = '-2'