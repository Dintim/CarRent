USE [master]
GO
/****** Object:  Database [car_rent]    Script Date: 08.02.2019 22:55:22 ******/
CREATE DATABASE [car_rent] 
GO
USE [car_rent]
GO
/****** Object:  User [petrov]    Script Date: 08.02.2019 22:55:22 ******/
CREATE USER [petrov] FOR LOGIN [manager] WITH DEFAULT_SCHEMA=[dbo]
GO
/****** Object:  User [omarova]    Script Date: 08.02.2019 22:55:22 ******/
CREATE USER [omarova] FOR LOGIN [accountant] WITH DEFAULT_SCHEMA=[dbo]
GO
/****** Object:  User [ivanov]    Script Date: 08.02.2019 22:55:22 ******/
CREATE USER [ivanov] FOR LOGIN [client] WITH DEFAULT_SCHEMA=[dbo]
GO
/****** Object:  DatabaseRole [manager]    Script Date: 08.02.2019 22:55:22 ******/
CREATE ROLE [manager]
GO
/****** Object:  DatabaseRole [client]    Script Date: 08.02.2019 22:55:22 ******/
CREATE ROLE [client]
GO
/****** Object:  DatabaseRole [accountant]    Script Date: 08.02.2019 22:55:22 ******/
CREATE ROLE [accountant]
GO
ALTER ROLE [manager] ADD MEMBER [petrov]
GO
ALTER ROLE [accountant] ADD MEMBER [omarova]
GO
ALTER ROLE [client] ADD MEMBER [ivanov]
GO
/****** Object:  StoredProcedure [dbo].[PR_client_reminder]    Script Date: 08.02.2019 22:55:22 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create proc [dbo].[PR_client_reminder] @days int
as
if exists (select 1 from rent_contracts 
where date_in is null
and DATEDIFF(day, getdate(),DATEADD(day, rc_days, date_out))=@days)

begin
declare @email nvarchar(100), @client nvarchar(100), @car nvarchar(100), @car_number nvarchar(100),
@date_in nvarchar(100), @body nvarchar(max) 

declare cr cursor for
select cl.email,cl.cl_name+' '+cl.cl_surname, cb.brand_name+' '+cm.model_name+' '+convert(varchar,year(cm.release_year)),
convert(varchar,c.car_number), convert(varchar,DATEADD(day, r.rc_days, r.date_out),104) 
from rent_contracts r, clients cl, cars c, car_models cm, car_brands cb
where r.cl_id=cl.cl_id
and r.car_id=c.car_id
and c.model_id=cm.model_id
and cm.brand_id=cb.brand_id 
and r.date_in is null
and DATEDIFF(day, getdate(),DATEADD(day, r.rc_days, r.date_out))=@days

open cr
fetch next from cr into @email, @client, @car, @car_number,@date_in
while @@FETCH_STATUS=0
begin
set @body='<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
</head>
<body>
<p>Здравствуйте, <b>'+@client+'</b>!</p>
<p>Срок аренды автомобиля </p>'+@car+', госномер '+@car_number+' истекает через '+@days+' дня</p>
<p>Пожалуйста, не забудьте вернуть автомобиль </p>'+@date_in+
'<p>С уважением, CAR RENT</p>
</body>
</html>'
EXEC msdb.dbo.sp_send_dbmail
			@recipients = @email,
			@subject = 'Срок аренды автомобиля истекает',
			@body = @body,
		-- Формат письма может быть либо 'HTML', либо 'TEXT'
			@body_format = 'HTML',
		-- При необходимости к письму можно прикрепить файл
			--@file_attachments ='C:\attachment.jpg',
		-- Укажем созданный ранее профиль администратора почтовых рассылок
			@profile_name = 'mailru';
fetch next from cr into @email, @client, @car, @car_number,@date_in
end
close cr
deallocate cr
end
GO
/****** Object:  StoredProcedure [dbo].[PR_send_list_debtors]    Script Date: 08.02.2019 22:55:22 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE proc [dbo].[PR_send_list_debtors]
as
if exists (select 1 from rent_contracts where date_in is null 
and DATEADD(day,rc_days, date_out)<getdate())
begin
declare @rc_id varchar(50), @car nvarchar(255), @car_number nvarchar(50), 
@client nvarchar(255), @cl_tel nvarchar(50), @date_out nvarchar(50), 
@rc_days nvarchar(50), @delay_days nvarchar(50),
@dir_email nvarchar(50), @body nvarchar(max)
select @dir_email=emp_email from employees where emp_usr='dir'
set @body='<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
</head>
<body>
<p><b>Список должников!</b></p>
<table border="1", solid>
<tr><th>№ контракта</th><th>Машина</th><th>Госномер</th><th>Клиент</th><th>Тел</th><th>Дата</th><th>Срок аренды</th><th>Просрочено дней</th></tr>'

declare cr cursor for
select convert(varchar,r.rc_id) rc_num, 
cb.brand_name+' '+cm.model_name+' '+convert(varchar,year(cm.release_year)) car, c.car_number,
cl.cl_name+' '+cl.cl_surname client, convert(nvarchar,cl.cl_tel) cl_tel, 
convert(nvarchar,r.date_out,104) date_out, convert(nvarchar,r.rc_days) rc_days, 
convert(nvarchar,datediff(day,DATEADD(day, r.rc_days, r.date_out),getdate())) delay_days 
from rent_contracts r, clients cl, cars c, car_models cm, car_brands cb
where r.car_id=c.car_id
and r.cl_id=cl.cl_id
and c.model_id=cm.model_id
and cm.brand_id=cb.brand_id
and r.date_in is null
and DATEADD(day, r.rc_days, r.date_out)<getdate()
open cr
fetch next from cr into @rc_id,@car,@car_number,@client,@cl_tel,@date_out,@rc_days,@delay_days
while @@FETCH_STATUS=0 
begin
set @body=@body+'<tr><td>'+@rc_id+'</td><td>'+@car+'</td><td>'+@car_number+'</td><td>'+@client+'</td><td>'+@cl_tel+'</td><td>'+@date_out+'</td><td>'+@rc_days+'</td><td>'+@delay_days+'</td></tr>'
fetch next from cr into @rc_id,@car,@car_number,@client,@cl_tel,@date_out,@rc_days,@delay_days
end
close cr
deallocate cr

set @body=@body+'</table>
<p>Дата составления отчета: </p>' +convert(varchar,getdate(),104)+
'</body>
</html>'
EXEC msdb.dbo.sp_send_dbmail
			@recipients = @dir_email,
			@subject = 'Список должников',
			@body = @body,
		-- Формат письма может быть либо 'HTML', либо 'TEXT'
			@body_format = 'HTML',
		-- При необходимости к письму можно прикрепить файл
			--@file_attachments ='C:\attachment.jpg',
		-- Укажем созданный ранее профиль администратора почтовых рассылок
			@profile_name = 'mailru';
end
else
print 'list does not exist'
GO
/****** Object:  Table [dbo].[accidents]    Script Date: 08.02.2019 22:55:22 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[accidents](
	[accid_id] [int] IDENTITY(1,1) NOT NULL,
	[rc_id] [int] NOT NULL,
	[accident_date] [date] NOT NULL,
	[damage] [varchar](200) NOT NULL,
	[damage_cost] [int] NOT NULL,
 CONSTRAINT [PK_accidents] PRIMARY KEY CLUSTERED 
(
	[accid_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[car_body]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[car_body](
	[body_id] [int] IDENTITY(1,1) NOT NULL,
	[body_name] [varchar](40) NOT NULL,
 CONSTRAINT [PK_car_body] PRIMARY KEY CLUSTERED 
(
	[body_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[car_brands]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[car_brands](
	[brand_id] [int] IDENTITY(1,1) NOT NULL,
	[brand_name] [varchar](40) NOT NULL,
 CONSTRAINT [PK_car_brands] PRIMARY KEY CLUSTERED 
(
	[brand_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[car_colors]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[car_colors](
	[color_id] [int] IDENTITY(1,1) NOT NULL,
	[color_name] [varchar](40) NOT NULL,
 CONSTRAINT [PK_car_colors] PRIMARY KEY CLUSTERED 
(
	[color_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[car_models]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[car_models](
	[model_id] [int] IDENTITY(1,1) NOT NULL,
	[model_name] [varchar](40) NOT NULL,
	[release_year] [date] NOT NULL,
	[engine_capacity] [float] NOT NULL,
	[engtype_id] [int] NOT NULL,
	[body_id] [int] NOT NULL,
	[brand_id] [int] NOT NULL,
 CONSTRAINT [PK_car_models] PRIMARY KEY CLUSTERED 
(
	[model_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[cars]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[cars](
	[car_id] [int] IDENTITY(1,1) NOT NULL,
	[car_number] [varchar](7) NOT NULL,
	[model_id] [int] NOT NULL,
	[color_id] [int] NOT NULL,
 CONSTRAINT [PK_cars] PRIMARY KEY CLUSTERED 
(
	[car_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[clients]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[clients](
	[cl_id] [int] IDENTITY(1,1) NOT NULL,
	[cl_name] [varchar](40) NOT NULL,
	[cl_surname] [varchar](50) NOT NULL,
	[cl_IIN] [varchar](12) NOT NULL,
	[cl_tel] [int] NOT NULL,
	[cl_adress] [varchar](100) NOT NULL,
	[cl_driver_license] [varchar](10) NOT NULL,
	[cl_usr] [varchar](100) NULL,
	[email] [varchar](100) NULL,
 CONSTRAINT [PK_clients] PRIMARY KEY CLUSTERED 
(
	[cl_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[employees]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[employees](
	[emp_id] [int] IDENTITY(1,1) NOT NULL,
	[emp_name] [varchar](40) NOT NULL,
	[emp_surname] [varchar](50) NOT NULL,
	[emp_position] [varchar](100) NULL,
	[emp_usr] [varchar](100) NULL,
	[emp_email] [varchar](100) NULL,
 CONSTRAINT [PK_employees] PRIMARY KEY CLUSTERED 
(
	[emp_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[engine_types]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[engine_types](
	[engtype_id] [int] IDENTITY(1,1) NOT NULL,
	[engtype_name] [varchar](40) NOT NULL,
 CONSTRAINT [PK_engine_types] PRIMARY KEY CLUSTERED 
(
	[engtype_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[invoices]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[invoices](
	[inv_id] [int] IDENTITY(1,1) NOT NULL,
	[rc_id] [int] NOT NULL,
	[inv_date] [date] NOT NULL,
	[inv_price] [int] NOT NULL,
	[inv_note] [varchar](100) NULL,
 CONSTRAINT [PK_invoices] PRIMARY KEY CLUSTERED 
(
	[inv_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[rent_contracts]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[rent_contracts](
	[rc_id] [int] IDENTITY(1,1) NOT NULL,
	[emp_id] [int] NOT NULL,
	[car_id] [int] NOT NULL,
	[cl_id] [int] NOT NULL,
	[date_out] [date] NOT NULL,
	[rc_days] [int] NOT NULL,
	[date_in] [date] NULL,
 CONSTRAINT [PK_rent_contracts] PRIMARY KEY CLUSTERED 
(
	[rc_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  View [dbo].[v_accidents_for_cl]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create view [dbo].[v_accidents_for_cl] as
select a.accid_id, r.rc_id, c.car_number, cb.brand_name, cm.model_name, cc.color_name,
cm.release_year, a.accident_date, a.damage, a.damage_cost 
from accidents a, rent_contracts r, clients cl,cars c, car_models cm, car_brands cb, car_colors cc
where a.rc_id=r.rc_id
and r.cl_id=cl.cl_id
and r.car_id=c.car_id
and c.color_id=cc.color_id
and c.model_id=cm.model_id
and cm.brand_id=cb.brand_id
and cl.cl_usr=SUSER_SNAME()
GO
/****** Object:  View [dbo].[v_available_cars]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create view [dbo].[v_available_cars] as
select c.car_id, cb.brand_name, cm.model_name, cc.color_name, b.body_name,
cm.release_year, cm.engine_capacity, e.engtype_name 
from cars c, car_brands cb, car_models cm, car_colors cc, car_body b, engine_types e
where c.model_id=cm.model_id
and c.color_id=cc.color_id
and cm.brand_id=cb.brand_id
and cm.body_id=b.body_id
and cm.engtype_id=e.engtype_id
and c.car_id not in (select car_id from rent_contracts 
where date_in>=getdate() or date_in is null)
GO
/****** Object:  View [dbo].[v_invoices_for_cl]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE view [dbo].[v_invoices_for_cl] as
select i.inv_id, r.rc_id, c.car_number, cb.brand_name, cm.model_name, cc.color_name, cm.release_year,
i.inv_date, i.inv_price, i.inv_note 
from invoices i, rent_contracts r, clients cl, cars c, car_models cm, car_brands cb, car_colors cc
where i.rc_id=r.rc_id
and r.cl_id=cl.cl_id
and r.car_id=c.car_id
and c.model_id=cm.model_id
and c.color_id=cc.color_id
and cm.brand_id=cb.brand_id
and cl.cl_usr=SUSER_SNAME()
GO
/****** Object:  View [dbo].[v_rent_contracts_for_cl]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create view [dbo].[v_rent_contracts_for_cl] as
select r.rc_id, e.emp_surname, e.emp_name, cb.brand_name, cm.model_name, cm.release_year, cc.color_name,
r.date_out, r.rc_days, r.date_in 
from rent_contracts r, employees e, cars c, clients cl, car_models cm, car_brands cb, car_colors cc
where r.car_id=c.car_id
and r.cl_id=cl.cl_id
and r.emp_id=e.emp_id
and c.model_id=cm.model_id
and c.color_id=cc.color_id
and cm.brand_id=cb.brand_id
and cl.cl_usr=SUSER_SNAME()
GO
/****** Object:  View [dbo].[v_rent_contracts_for_emp]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create view [dbo].[v_rent_contracts_for_emp] as
select r.rc_id, c.car_number, cb.brand_name, cm.model_name, cc.color_name, cm.release_year,
cl.cl_surname, cl.cl_name, cl.cl_tel, r.date_out, r.rc_days, r.date_in 
from rent_contracts r, employees e, clients cl,cars c, car_models cm, car_brands cb, car_colors cc
where r.emp_id=e.emp_id
and r.cl_id=cl.cl_id
and r.car_id=c.car_id
and c.color_id=cc.color_id
and c.model_id=cm.model_id
and cm.brand_id=cb.brand_id
and e.emp_usr=SUSER_SNAME()
GO
/****** Object:  View [dbo].[v_risk_clients]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create view [dbo].[v_risk_clients] as
select cl_name, cl_surname, cl_tel, cl_adress, cl_driver_license from clients
where cl_id in (select r.cl_id from rent_contracts r, employees e
where r.emp_id=e.emp_id
and r.date_in is null
and e.emp_usr=SUSER_SNAME())
GO
SET IDENTITY_INSERT [dbo].[accidents] ON 

INSERT [dbo].[accidents] ([accid_id], [rc_id], [accident_date], [damage], [damage_cost]) VALUES (1, 4, CAST(0x633D0B00 AS Date), N'помят передний бамбер', 50000)
INSERT [dbo].[accidents] ([accid_id], [rc_id], [accident_date], [damage], [damage_cost]) VALUES (2, 10, CAST(0xB33D0B00 AS Date), N'разбита правая задняя фара', 15000)
SET IDENTITY_INSERT [dbo].[accidents] OFF
SET IDENTITY_INSERT [dbo].[car_body] ON 

INSERT [dbo].[car_body] ([body_id], [body_name]) VALUES (7, N'внедорожник')
INSERT [dbo].[car_body] ([body_id], [body_name]) VALUES (3, N'кроссовер')
INSERT [dbo].[car_body] ([body_id], [body_name]) VALUES (6, N'купе')
INSERT [dbo].[car_body] ([body_id], [body_name]) VALUES (4, N'минивэн')
INSERT [dbo].[car_body] ([body_id], [body_name]) VALUES (1, N'седан')
INSERT [dbo].[car_body] ([body_id], [body_name]) VALUES (2, N'универсал')
INSERT [dbo].[car_body] ([body_id], [body_name]) VALUES (5, N'хэтчбек')
SET IDENTITY_INSERT [dbo].[car_body] OFF
SET IDENTITY_INSERT [dbo].[car_brands] ON 

INSERT [dbo].[car_brands] ([brand_id], [brand_name]) VALUES (2, N'Audi')
INSERT [dbo].[car_brands] ([brand_id], [brand_name]) VALUES (4, N'BMW')
INSERT [dbo].[car_brands] ([brand_id], [brand_name]) VALUES (5, N'Honda')
INSERT [dbo].[car_brands] ([brand_id], [brand_name]) VALUES (3, N'Nissan')
INSERT [dbo].[car_brands] ([brand_id], [brand_name]) VALUES (6, N'Renault')
INSERT [dbo].[car_brands] ([brand_id], [brand_name]) VALUES (1, N'Toyota')
SET IDENTITY_INSERT [dbo].[car_brands] OFF
SET IDENTITY_INSERT [dbo].[car_colors] ON 

INSERT [dbo].[car_colors] ([color_id], [color_name]) VALUES (2, N'белый')
INSERT [dbo].[car_colors] ([color_id], [color_name]) VALUES (5, N'зеленый')
INSERT [dbo].[car_colors] ([color_id], [color_name]) VALUES (7, N'золотистый')
INSERT [dbo].[car_colors] ([color_id], [color_name]) VALUES (1, N'красный')
INSERT [dbo].[car_colors] ([color_id], [color_name]) VALUES (4, N'серый')
INSERT [dbo].[car_colors] ([color_id], [color_name]) VALUES (6, N'синий')
INSERT [dbo].[car_colors] ([color_id], [color_name]) VALUES (3, N'черный')
SET IDENTITY_INSERT [dbo].[car_colors] OFF
SET IDENTITY_INSERT [dbo].[car_models] ON 

INSERT [dbo].[car_models] ([model_id], [model_name], [release_year], [engine_capacity], [engtype_id], [body_id], [brand_id]) VALUES (1, N'Campry', CAST(0x6E390B00 AS Date), 2.5, 1, 1, 1)
INSERT [dbo].[car_models] ([model_id], [model_name], [release_year], [engine_capacity], [engtype_id], [body_id], [brand_id]) VALUES (2, N'Highlander', CAST(0x712F0B00 AS Date), 3.5, 1, 3, 1)
INSERT [dbo].[car_models] ([model_id], [model_name], [release_year], [engine_capacity], [engtype_id], [body_id], [brand_id]) VALUES (3, N'Land Cruiser', CAST(0xDB3A0B00 AS Date), 4.6, 1, 7, 1)
INSERT [dbo].[car_models] ([model_id], [model_name], [release_year], [engine_capacity], [engtype_id], [body_id], [brand_id]) VALUES (4, N'X5', CAST(0x26350B00 AS Date), 3, 1, 7, 4)
INSERT [dbo].[car_models] ([model_id], [model_name], [release_year], [engine_capacity], [engtype_id], [body_id], [brand_id]) VALUES (5, N'X6', CAST(0xDF300B00 AS Date), 4.4, 1, 7, 4)
INSERT [dbo].[car_models] ([model_id], [model_name], [release_year], [engine_capacity], [engtype_id], [body_id], [brand_id]) VALUES (6, N'535', CAST(0x4C320B00 AS Date), 3, 1, 1, 4)
INSERT [dbo].[car_models] ([model_id], [model_name], [release_year], [engine_capacity], [engtype_id], [body_id], [brand_id]) VALUES (7, N'S5', CAST(0xDF300B00 AS Date), 4.2, 2, 6, 2)
INSERT [dbo].[car_models] ([model_id], [model_name], [release_year], [engine_capacity], [engtype_id], [body_id], [brand_id]) VALUES (8, N'A6', CAST(0x2A2B0B00 AS Date), 2.4, 1, 2, 2)
INSERT [dbo].[car_models] ([model_id], [model_name], [release_year], [engine_capacity], [engtype_id], [body_id], [brand_id]) VALUES (9, N'Duster', CAST(0x6E390B00 AS Date), 2, 1, 7, 6)
INSERT [dbo].[car_models] ([model_id], [model_name], [release_year], [engine_capacity], [engtype_id], [body_id], [brand_id]) VALUES (10, N'Captur', CAST(0xDB3A0B00 AS Date), 2, 5, 3, 6)
INSERT [dbo].[car_models] ([model_id], [model_name], [release_year], [engine_capacity], [engtype_id], [body_id], [brand_id]) VALUES (11, N'Sandero', CAST(0x94360B00 AS Date), 2, 2, 5, 6)
SET IDENTITY_INSERT [dbo].[car_models] OFF
SET IDENTITY_INSERT [dbo].[cars] ON 

INSERT [dbo].[cars] ([car_id], [car_number], [model_id], [color_id]) VALUES (1, N'A133ERT', 4, 1)
INSERT [dbo].[cars] ([car_id], [car_number], [model_id], [color_id]) VALUES (2, N'A135ETT', 4, 3)
INSERT [dbo].[cars] ([car_id], [car_number], [model_id], [color_id]) VALUES (3, N'A045ASD', 7, 3)
INSERT [dbo].[cars] ([car_id], [car_number], [model_id], [color_id]) VALUES (4, N'A111SSS', 9, 7)
INSERT [dbo].[cars] ([car_id], [car_number], [model_id], [color_id]) VALUES (5, N'A456DFG', 9, 6)
INSERT [dbo].[cars] ([car_id], [car_number], [model_id], [color_id]) VALUES (6, N'A789TFG', 1, 3)
INSERT [dbo].[cars] ([car_id], [car_number], [model_id], [color_id]) VALUES (7, N'A147RTD', 2, 2)
INSERT [dbo].[cars] ([car_id], [car_number], [model_id], [color_id]) VALUES (8, N'A416EFX', 3, 6)
INSERT [dbo].[cars] ([car_id], [car_number], [model_id], [color_id]) VALUES (10, N'A444EFX', 5, 4)
INSERT [dbo].[cars] ([car_id], [car_number], [model_id], [color_id]) VALUES (11, N'A213UBV', 6, 3)
INSERT [dbo].[cars] ([car_id], [car_number], [model_id], [color_id]) VALUES (12, N'A333TTT', 8, 6)
INSERT [dbo].[cars] ([car_id], [car_number], [model_id], [color_id]) VALUES (13, N'A321WER', 10, 1)
INSERT [dbo].[cars] ([car_id], [car_number], [model_id], [color_id]) VALUES (14, N'A054AHG', 11, 4)
SET IDENTITY_INSERT [dbo].[cars] OFF
SET IDENTITY_INSERT [dbo].[clients] ON 

INSERT [dbo].[clients] ([cl_id], [cl_name], [cl_surname], [cl_IIN], [cl_tel], [cl_adress], [cl_driver_license], [cl_usr], [email]) VALUES (3, N'Иван', N'Иванов', N'701104100123', 1234556, N'г.Алматы, пр.Абая, д.105, кв.17', N'AN12345', N'ivanov', N'muk_dinara@mail.ru')
INSERT [dbo].[clients] ([cl_id], [cl_name], [cl_surname], [cl_IIN], [cl_tel], [cl_adress], [cl_driver_license], [cl_usr], [email]) VALUES (5, N'Ермек', N'Ермеков', N'800509123456', 4567891, N'г.Алматы, 11 мк-он, д.60, кв.5', N'AN18456', NULL, N'dina.mukasheva83@gmail.com')
INSERT [dbo].[clients] ([cl_id], [cl_name], [cl_surname], [cl_IIN], [cl_tel], [cl_adress], [cl_driver_license], [cl_usr], [email]) VALUES (9, N'Олег', N'Ким', N'780111456123', 3290505, N'г.Алматы, пр.Достык, д.7, кв.77', N'AN22451', NULL, N'muk_dinara@mail.ru')
SET IDENTITY_INSERT [dbo].[clients] OFF
SET IDENTITY_INSERT [dbo].[employees] ON 

INSERT [dbo].[employees] ([emp_id], [emp_name], [emp_surname], [emp_position], [emp_usr], [emp_email]) VALUES (1, N'Петр', N'Петров', N'менеджер', N'petrov', NULL)
INSERT [dbo].[employees] ([emp_id], [emp_name], [emp_surname], [emp_position], [emp_usr], [emp_email]) VALUES (2, N'Тимур', N'Тимуров', N'менеджер', NULL, NULL)
INSERT [dbo].[employees] ([emp_id], [emp_name], [emp_surname], [emp_position], [emp_usr], [emp_email]) VALUES (3, N'Дана', N'Омарова', N'бухгалтер', N'omarova', NULL)
INSERT [dbo].[employees] ([emp_id], [emp_name], [emp_surname], [emp_position], [emp_usr], [emp_email]) VALUES (4, N'Динара', N'Мукашева', N'директор', N'dir', N'muk_dinara@mail.ru')
SET IDENTITY_INSERT [dbo].[employees] OFF
SET IDENTITY_INSERT [dbo].[engine_types] ON 

INSERT [dbo].[engine_types] ([engtype_id], [engtype_name]) VALUES (1, N'бензин')
INSERT [dbo].[engine_types] ([engtype_id], [engtype_name]) VALUES (3, N'газ')
INSERT [dbo].[engine_types] ([engtype_id], [engtype_name]) VALUES (5, N'гибрид')
INSERT [dbo].[engine_types] ([engtype_id], [engtype_name]) VALUES (2, N'дизель')
INSERT [dbo].[engine_types] ([engtype_id], [engtype_name]) VALUES (4, N'электричество')
SET IDENTITY_INSERT [dbo].[engine_types] OFF
SET IDENTITY_INSERT [dbo].[invoices] ON 

INSERT [dbo].[invoices] ([inv_id], [rc_id], [inv_date], [inv_price], [inv_note]) VALUES (1, 1, CAST(0x223D0B00 AS Date), 75000, N'initial rent')
INSERT [dbo].[invoices] ([inv_id], [rc_id], [inv_date], [inv_price], [inv_note]) VALUES (2, 2, CAST(0x453D0B00 AS Date), 150000, N'initial rent')
INSERT [dbo].[invoices] ([inv_id], [rc_id], [inv_date], [inv_price], [inv_note]) VALUES (3, 3, CAST(0x473D0B00 AS Date), 150000, N'initial rent')
INSERT [dbo].[invoices] ([inv_id], [rc_id], [inv_date], [inv_price], [inv_note]) VALUES (4, 4, CAST(0x513D0B00 AS Date), 100000, N'initial rent')
INSERT [dbo].[invoices] ([inv_id], [rc_id], [inv_date], [inv_price], [inv_note]) VALUES (5, 5, CAST(0x5E3D0B00 AS Date), 150000, N'initial rent')
INSERT [dbo].[invoices] ([inv_id], [rc_id], [inv_date], [inv_price], [inv_note]) VALUES (6, 6, CAST(0x633D0B00 AS Date), 150000, N'initial rent')
INSERT [dbo].[invoices] ([inv_id], [rc_id], [inv_date], [inv_price], [inv_note]) VALUES (7, 7, CAST(0x803D0B00 AS Date), 50000, N'initial rent')
INSERT [dbo].[invoices] ([inv_id], [rc_id], [inv_date], [inv_price], [inv_note]) VALUES (8, 8, CAST(0x973D0B00 AS Date), 100000, N'initial rent')
INSERT [dbo].[invoices] ([inv_id], [rc_id], [inv_date], [inv_price], [inv_note]) VALUES (9, 9, CAST(0xA93D0B00 AS Date), 100000, N'initial rent')
INSERT [dbo].[invoices] ([inv_id], [rc_id], [inv_date], [inv_price], [inv_note]) VALUES (10, 10, CAST(0xAA3D0B00 AS Date), 50000, N'initial rent')
INSERT [dbo].[invoices] ([inv_id], [rc_id], [inv_date], [inv_price], [inv_note]) VALUES (11, 11, CAST(0xB43D0B00 AS Date), 150000, N'initial rent')
INSERT [dbo].[invoices] ([inv_id], [rc_id], [inv_date], [inv_price], [inv_note]) VALUES (12, 4, CAST(0x8E3D0B00 AS Date), 205000, N'add fee for late return')
INSERT [dbo].[invoices] ([inv_id], [rc_id], [inv_date], [inv_price], [inv_note]) VALUES (13, 5, CAST(0x8F3D0B00 AS Date), 95000, N'add fee for late return')
INSERT [dbo].[invoices] ([inv_id], [rc_id], [inv_date], [inv_price], [inv_note]) VALUES (14, 6, CAST(0x843D0B00 AS Date), 15000, N'add fee for late return')
INSERT [dbo].[invoices] ([inv_id], [rc_id], [inv_date], [inv_price], [inv_note]) VALUES (15, 10, CAST(0xBA3D0B00 AS Date), 30000, N'add fee for late return')
INSERT [dbo].[invoices] ([inv_id], [rc_id], [inv_date], [inv_price], [inv_note]) VALUES (16, 4, CAST(0x633D0B00 AS Date), 50000, N'add fee for damage')
INSERT [dbo].[invoices] ([inv_id], [rc_id], [inv_date], [inv_price], [inv_note]) VALUES (17, 10, CAST(0xB33D0B00 AS Date), 15000, N'add fee for damage')
INSERT [dbo].[invoices] ([inv_id], [rc_id], [inv_date], [inv_price], [inv_note]) VALUES (19, 13, CAST(0x463F0B00 AS Date), 150000, N'initial rent')
SET IDENTITY_INSERT [dbo].[invoices] OFF
SET IDENTITY_INSERT [dbo].[rent_contracts] ON 

INSERT [dbo].[rent_contracts] ([rc_id], [emp_id], [car_id], [cl_id], [date_out], [rc_days], [date_in]) VALUES (1, 1, 5, 5, CAST(0x223D0B00 AS Date), 15, CAST(0x253D0B00 AS Date))
INSERT [dbo].[rent_contracts] ([rc_id], [emp_id], [car_id], [cl_id], [date_out], [rc_days], [date_in]) VALUES (2, 1, 8, 3, CAST(0x453D0B00 AS Date), 30, CAST(0x5E3D0B00 AS Date))
INSERT [dbo].[rent_contracts] ([rc_id], [emp_id], [car_id], [cl_id], [date_out], [rc_days], [date_in]) VALUES (3, 1, 2, 5, CAST(0x473D0B00 AS Date), 30, CAST(0x643D0B00 AS Date))
INSERT [dbo].[rent_contracts] ([rc_id], [emp_id], [car_id], [cl_id], [date_out], [rc_days], [date_in]) VALUES (4, 1, 3, 9, CAST(0x513D0B00 AS Date), 20, CAST(0x8E3D0B00 AS Date))
INSERT [dbo].[rent_contracts] ([rc_id], [emp_id], [car_id], [cl_id], [date_out], [rc_days], [date_in]) VALUES (5, 2, 10, 3, CAST(0x5E3D0B00 AS Date), 30, CAST(0x8F3D0B00 AS Date))
INSERT [dbo].[rent_contracts] ([rc_id], [emp_id], [car_id], [cl_id], [date_out], [rc_days], [date_in]) VALUES (6, 2, 1, 9, CAST(0x633D0B00 AS Date), 30, CAST(0x843D0B00 AS Date))
INSERT [dbo].[rent_contracts] ([rc_id], [emp_id], [car_id], [cl_id], [date_out], [rc_days], [date_in]) VALUES (7, 2, 7, 3, CAST(0x803D0B00 AS Date), 10, CAST(0x893D0B00 AS Date))
INSERT [dbo].[rent_contracts] ([rc_id], [emp_id], [car_id], [cl_id], [date_out], [rc_days], [date_in]) VALUES (8, 2, 11, 5, CAST(0x973D0B00 AS Date), 20, CAST(0xAA3D0B00 AS Date))
INSERT [dbo].[rent_contracts] ([rc_id], [emp_id], [car_id], [cl_id], [date_out], [rc_days], [date_in]) VALUES (9, 1, 5, 3, CAST(0xA93D0B00 AS Date), 20, NULL)
INSERT [dbo].[rent_contracts] ([rc_id], [emp_id], [car_id], [cl_id], [date_out], [rc_days], [date_in]) VALUES (10, 1, 12, 9, CAST(0xAA3D0B00 AS Date), 10, CAST(0xBA3D0B00 AS Date))
INSERT [dbo].[rent_contracts] ([rc_id], [emp_id], [car_id], [cl_id], [date_out], [rc_days], [date_in]) VALUES (11, 2, 3, 5, CAST(0xB43D0B00 AS Date), 30, NULL)
INSERT [dbo].[rent_contracts] ([rc_id], [emp_id], [car_id], [cl_id], [date_out], [rc_days], [date_in]) VALUES (13, 1, 6, 9, CAST(0x463F0B00 AS Date), 30, NULL)
SET IDENTITY_INSERT [dbo].[rent_contracts] OFF
SET ANSI_PADDING ON

GO
/****** Object:  Index [UQ_BODY_NAME]    Script Date: 08.02.2019 22:55:23 ******/
ALTER TABLE [dbo].[car_body] ADD  CONSTRAINT [UQ_BODY_NAME] UNIQUE NONCLUSTERED 
(
	[body_name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [UQ_BRAND_NAME]    Script Date: 08.02.2019 22:55:23 ******/
ALTER TABLE [dbo].[car_brands] ADD  CONSTRAINT [UQ_BRAND_NAME] UNIQUE NONCLUSTERED 
(
	[brand_name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [UQ_COLOR_NAME]    Script Date: 08.02.2019 22:55:23 ******/
ALTER TABLE [dbo].[car_colors] ADD  CONSTRAINT [UQ_COLOR_NAME] UNIQUE NONCLUSTERED 
(
	[color_name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [UQ_MODEL_NAME]    Script Date: 08.02.2019 22:55:23 ******/
ALTER TABLE [dbo].[car_models] ADD  CONSTRAINT [UQ_MODEL_NAME] UNIQUE NONCLUSTERED 
(
	[model_name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [UQ_CAR_NUMBER]    Script Date: 08.02.2019 22:55:23 ******/
ALTER TABLE [dbo].[cars] ADD  CONSTRAINT [UQ_CAR_NUMBER] UNIQUE NONCLUSTERED 
(
	[car_number] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [UQ_CLIENT_ADRESS]    Script Date: 08.02.2019 22:55:23 ******/
ALTER TABLE [dbo].[clients] ADD  CONSTRAINT [UQ_CLIENT_ADRESS] UNIQUE NONCLUSTERED 
(
	[cl_adress] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [UQ_CLIENT_IIN]    Script Date: 08.02.2019 22:55:23 ******/
ALTER TABLE [dbo].[clients] ADD  CONSTRAINT [UQ_CLIENT_IIN] UNIQUE NONCLUSTERED 
(
	[cl_IIN] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [UQ_CLIENT_LICENSE]    Script Date: 08.02.2019 22:55:23 ******/
ALTER TABLE [dbo].[clients] ADD  CONSTRAINT [UQ_CLIENT_LICENSE] UNIQUE NONCLUSTERED 
(
	[cl_driver_license] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  Index [UQ_CLIENT_TEL]    Script Date: 08.02.2019 22:55:23 ******/
ALTER TABLE [dbo].[clients] ADD  CONSTRAINT [UQ_CLIENT_TEL] UNIQUE NONCLUSTERED 
(
	[cl_tel] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
SET ANSI_PADDING ON

GO
/****** Object:  Index [UQ_ENGINE_NAME]    Script Date: 08.02.2019 22:55:23 ******/
ALTER TABLE [dbo].[engine_types] ADD  CONSTRAINT [UQ_ENGINE_NAME] UNIQUE NONCLUSTERED 
(
	[engtype_name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
/****** Object:  Index [UQ_RENT_CONTRACT_CLIENT_CAR]    Script Date: 08.02.2019 22:55:23 ******/
ALTER TABLE [dbo].[rent_contracts] ADD  CONSTRAINT [UQ_RENT_CONTRACT_CLIENT_CAR] UNIQUE NONCLUSTERED 
(
	[car_id] ASC,
	[cl_id] ASC,
	[date_out] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[accidents] ADD  CONSTRAINT [DF_DATE_ACCIDENT]  DEFAULT (getdate()) FOR [accident_date]
GO
ALTER TABLE [dbo].[accidents] ADD  CONSTRAINT [DF_DAMAGE_ACCIDENT]  DEFAULT ('none') FOR [damage]
GO
ALTER TABLE [dbo].[accidents] ADD  CONSTRAINT [DF_DAMAGE_COST_ACCIDENT]  DEFAULT ((0)) FOR [damage_cost]
GO
ALTER TABLE [dbo].[car_models] ADD  CONSTRAINT [DF_RELEASE_YEAR_MODEL]  DEFAULT ('1990') FOR [release_year]
GO
ALTER TABLE [dbo].[car_models] ADD  CONSTRAINT [DF_ENGINE_CAPACITY_MODEL]  DEFAULT ((1)) FOR [engine_capacity]
GO
ALTER TABLE [dbo].[rent_contracts] ADD  CONSTRAINT [DF_DATE_OUT_CONTRACTS]  DEFAULT (getdate()) FOR [date_out]
GO
ALTER TABLE [dbo].[rent_contracts] ADD  CONSTRAINT [DF_DAYS_CONTRACT]  DEFAULT ((0)) FOR [rc_days]
GO
ALTER TABLE [dbo].[accidents]  WITH CHECK ADD  CONSTRAINT [FK_accidents_rent_contracts] FOREIGN KEY([rc_id])
REFERENCES [dbo].[rent_contracts] ([rc_id])
GO
ALTER TABLE [dbo].[accidents] CHECK CONSTRAINT [FK_accidents_rent_contracts]
GO
ALTER TABLE [dbo].[car_models]  WITH CHECK ADD  CONSTRAINT [FK_car_models_car_body] FOREIGN KEY([body_id])
REFERENCES [dbo].[car_body] ([body_id])
GO
ALTER TABLE [dbo].[car_models] CHECK CONSTRAINT [FK_car_models_car_body]
GO
ALTER TABLE [dbo].[car_models]  WITH CHECK ADD  CONSTRAINT [FK_car_models_car_brands] FOREIGN KEY([brand_id])
REFERENCES [dbo].[car_brands] ([brand_id])
GO
ALTER TABLE [dbo].[car_models] CHECK CONSTRAINT [FK_car_models_car_brands]
GO
ALTER TABLE [dbo].[car_models]  WITH CHECK ADD  CONSTRAINT [FK_car_models_engine_types] FOREIGN KEY([engtype_id])
REFERENCES [dbo].[engine_types] ([engtype_id])
GO
ALTER TABLE [dbo].[car_models] CHECK CONSTRAINT [FK_car_models_engine_types]
GO
ALTER TABLE [dbo].[cars]  WITH CHECK ADD  CONSTRAINT [FK_cars_car_colors] FOREIGN KEY([color_id])
REFERENCES [dbo].[car_colors] ([color_id])
GO
ALTER TABLE [dbo].[cars] CHECK CONSTRAINT [FK_cars_car_colors]
GO
ALTER TABLE [dbo].[cars]  WITH CHECK ADD  CONSTRAINT [FK_cars_car_models] FOREIGN KEY([model_id])
REFERENCES [dbo].[car_models] ([model_id])
GO
ALTER TABLE [dbo].[cars] CHECK CONSTRAINT [FK_cars_car_models]
GO
ALTER TABLE [dbo].[invoices]  WITH CHECK ADD  CONSTRAINT [FK_invoices_rent_contracts] FOREIGN KEY([rc_id])
REFERENCES [dbo].[rent_contracts] ([rc_id])
GO
ALTER TABLE [dbo].[invoices] CHECK CONSTRAINT [FK_invoices_rent_contracts]
GO
ALTER TABLE [dbo].[rent_contracts]  WITH CHECK ADD  CONSTRAINT [FK_rent_contracts_cars] FOREIGN KEY([car_id])
REFERENCES [dbo].[cars] ([car_id])
GO
ALTER TABLE [dbo].[rent_contracts] CHECK CONSTRAINT [FK_rent_contracts_cars]
GO
ALTER TABLE [dbo].[rent_contracts]  WITH CHECK ADD  CONSTRAINT [FK_rent_contracts_clients] FOREIGN KEY([cl_id])
REFERENCES [dbo].[clients] ([cl_id])
GO
ALTER TABLE [dbo].[rent_contracts] CHECK CONSTRAINT [FK_rent_contracts_clients]
GO
ALTER TABLE [dbo].[rent_contracts]  WITH CHECK ADD  CONSTRAINT [FK_rent_contracts_employees] FOREIGN KEY([emp_id])
REFERENCES [dbo].[employees] ([emp_id])
GO
ALTER TABLE [dbo].[rent_contracts] CHECK CONSTRAINT [FK_rent_contracts_employees]
GO
ALTER TABLE [dbo].[accidents]  WITH CHECK ADD  CONSTRAINT [CK_DATE_ACCIDENTS] CHECK  (([accident_date]>'2016'))
GO
ALTER TABLE [dbo].[accidents] CHECK CONSTRAINT [CK_DATE_ACCIDENTS]
GO
ALTER TABLE [dbo].[car_models]  WITH CHECK ADD  CONSTRAINT [CK_ENGINE_CAPACITY] CHECK  (([engine_capacity]>(0)))
GO
ALTER TABLE [dbo].[car_models] CHECK CONSTRAINT [CK_ENGINE_CAPACITY]
GO
ALTER TABLE [dbo].[car_models]  WITH CHECK ADD  CONSTRAINT [CK_RELEASE_YEAR_MODEL] CHECK  (([release_year]>'1900'))
GO
ALTER TABLE [dbo].[car_models] CHECK CONSTRAINT [CK_RELEASE_YEAR_MODEL]
GO
ALTER TABLE [dbo].[clients]  WITH CHECK ADD  CONSTRAINT [CK_CLIENT_IIN] CHECK  ((len([cl_IIN])=(12)))
GO
ALTER TABLE [dbo].[clients] CHECK CONSTRAINT [CK_CLIENT_IIN]
GO
ALTER TABLE [dbo].[rent_contracts]  WITH CHECK ADD  CONSTRAINT [CK_DATE_IN_CONTRACTS] CHECK  (([date_in]>[date_out]))
GO
ALTER TABLE [dbo].[rent_contracts] CHECK CONSTRAINT [CK_DATE_IN_CONTRACTS]
GO
ALTER TABLE [dbo].[rent_contracts]  WITH CHECK ADD  CONSTRAINT [CK_DATE_OUT_CONTRACTS] CHECK  (([date_out]>'2016'))
GO
ALTER TABLE [dbo].[rent_contracts] CHECK CONSTRAINT [CK_DATE_OUT_CONTRACTS]
GO
/****** Object:  Trigger [dbo].[TR_accidents_insert]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE trigger [dbo].[TR_accidents_insert]
on [dbo].[accidents]
after insert
as
insert into invoices
select rc_id, accident_date, damage_cost, 'add fee for damage' from accidents

declare @dir_email varchar(100), @cl_name varchar(100), @cl_surname varchar(100),
@car_id varchar(100),@brand varchar(100), @model varchar(100), @car_number varchar(100),
@ac_date varchar(100), @damage varchar(100), @cost varchar(100), @body nvarchar(max)

select @dir_email=emp_email from employees where emp_usr='dir'
select @car_id=r.car_id from inserted i, rent_contracts r where i.rc_id=r.rc_id
select @brand=cb.brand_name from cars c, car_models cm, car_brands cb where c.model_id=cm.model_id
and cm.brand_id=cb.brand_id and c.car_id=@car_id
select @model=cm.model_name from cars c, car_models cm where c.model_id=cm.model_id and c.car_id=@car_id
select @car_number=car_number from cars where car_id=@car_id
select @ac_date=convert(varchar,accident_date,104) from inserted
select @damage=damage from inserted
select @cost=damage_cost from inserted
set @body='Справка об ущербе от ДТП.

Дата происшествия: '+@ac_date+'
Автомобиль: '+@brand+' '+@model+', госномер '+@car_number+'
ФИО клиента: '+@cl_name+' '+@cl_surname+'
Ущерб: '+@damage+'
Стоимость ущерба: '+@cost+'

Информация об ущербе отправлена в бухгалтерию.'

EXEC msdb.dbo.sp_send_dbmail
			@recipients = @dir_email,
			@subject = 'Повреждения автомобиля в ДТП',
			@body = @body,		
			@body_format = 'text',
			@profile_name = 'mailru';
GO
/****** Object:  Trigger [dbo].[TR_rent_conracts_insert]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE trigger [dbo].[TR_rent_conracts_insert]
on [dbo].[rent_contracts]
after insert
as
insert into invoices
select rc_id, date_out, rc_days*5000, 'initial rent' from inserted

declare @cl_id int, @name varchar(50), @surname varchar(50), @email varchar(100), @car_id int,
@brand varchar(50), @model varchar(50), @car_number varchar(50), @date_in varchar(50),
@body nvarchar(max)
select @cl_id=cl_id from inserted
select @name=cl_name from clients where cl_id=@cl_id
select @surname=cl_surname from clients where cl_id=@cl_id
select @email=email from clients where cl_id=@cl_id

select @car_id=car_id from inserted
select @brand=cb.brand_name from cars c, car_models cm, car_brands cb where c.model_id=cm.model_id
and cm.brand_id=cb.brand_id and c.car_id=@car_id
select @model=cm.model_name from cars c, car_models cm where c.model_id=cm.model_id and c.car_id=@car_id
select @car_number=car_number from cars where car_id=@car_id
select @date_in=convert(varchar,DATEADD(day,rc_days,date_out),104) from inserted
set @body='Здравствуйте, '+@name+' '+@surname+'

Вы взяли в аренду автомобиль '+@brand+' '+@model+' госномер: '+@car_number+'
Срок аренды заканчивается: '+@date_in+'. Пожалуйста, не забудьте вернуть автомобиль вовремя.

Приятных вам поездок!
С уважением,
CAR RENT'
EXEC msdb.dbo.sp_send_dbmail
			@recipients = @email,
			@subject = 'Вы взяли автомобиль в аренду от CAR RENT',
			@body = @body,		
			@body_format = 'text',
			@profile_name = 'mailru';

GO
/****** Object:  Trigger [dbo].[TR_rent_contracts_update]    Script Date: 08.02.2019 22:55:23 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE trigger [dbo].[TR_rent_contracts_update]
on [dbo].[rent_contracts]
after update
as
insert into invoices
select rc_id, date_in,(DATEDIFF(day,date_out, date_in)-rc_days)*5000, 'add fee for late return'
from rent_contracts
where (DATEDIFF(day,date_out, date_in)-rc_days)>0

declare @cl_id int, @name varchar(50), @surname varchar(50), @email varchar(100), @car_id int,
@brand varchar(50), @model varchar(50), @car_number varchar(50), @date_out varchar(50),
@body nvarchar(max), @datediff int
select @cl_id=cl_id from inserted
select @name=cl_name from clients where cl_id=@cl_id
select @surname=cl_surname from clients where cl_id=@cl_id
select @email=email from clients where cl_id=@cl_id

select @car_id=car_id from inserted
select @brand=cb.brand_name from cars c, car_models cm, car_brands cb where c.model_id=cm.model_id
and cm.brand_id=cb.brand_id and c.car_id=@car_id
select @model=cm.model_name from cars c, car_models cm where c.model_id=cm.model_id and c.car_id=@car_id
select @car_number=car_number from cars where car_id=@car_id
select @date_out=date_out from inserted
select @datediff=(DATEDIFF(day,date_out, date_in)-rc_days) from inserted
set @body='Здравствуйте, '+@name+' '+@surname+'

Вы вернули взятый в аренду автомобиль '+@brand+' '+@model+' госномер: '+@car_number+'
Дата возврата: '+@date_out
if (@datediff>0) 
set @body=@body+'. Вы просрочили '+@datediff+' дней. 
Дополнительная сумма оплаты за поздний возврат: '+@datediff*5000+' тенге.

Спасибо, что воспользовались услугами нашей компании!
С уважением,
CAR RENT'
else
set @body=@body+'. Вы вернули автомобиль вовремя.

Спасибо, что воспользовались услугами нашей компании!
С уважением,
CAR RENT'


EXEC msdb.dbo.sp_send_dbmail
			@recipients = @email,
			@subject = 'Вы вернули автомобиль CAR RENT',
			@body = @body,		
			@body_format = 'text',
			@profile_name = 'mailru';

GO
USE [master]
GO
ALTER DATABASE [car_rent] SET  READ_WRITE 
GO
