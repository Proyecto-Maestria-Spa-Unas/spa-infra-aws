# Evidencias de validacion - QA remoto AWS

## 1. Informacion general

- Proyecto: SPA UNAS.
- Fecha de validacion: 2026-11-24.
- Region AWS: us-east-1.
- Proyecto CodeBuild: spa-qa-remoto.
- Rama: feature/qa-remoto.

## 2. Despliegue con Terraform

- Terraform validate: SUCCESS.
- Terraform plan: 6 to add, 0 to change, 0 to destroy.
- Terraform apply: 6 added, 0 changed, 0 destroyed.

## 3. Prueba de humo

- Suite: humo.
- Estado: SUCCEEDED.
- Fase: COMPLETED.
- Inicio: 13:07:35 (UTC-5).
- Fin: 13:08:46 (UTC-5).
- Duracion aproximada: 71 segundos.

## 4. Resultados tecnicos

| Componente | Version | Resultado |
|---|---|---|
| Python | 3.12.16 | PASS |
| Node.js | 22.23.4 | PASS |
| npm | 11.21.1 | PASS |
| Git | 2.56.0 | PASS |
| Docker | 29.9.2 | PASS |
| PostgreSQL | 16.4 | PASS |
| PostGIS | 3.4.3 | PASS |
| Consulta espacial | POINT(1 2) | PASS |
| Limpieza de contenedor y volumenes | Confirmada | PASS |

Resultado final:

INFRASTRUCTURE SMOKE TEST: PASSED

## 5. Control de costos

- Presupuesto mensual: USD 10.
- Alertas: 50%, 80% y 100%.
- Ejecuciones concurrentes: 1.
- Tiempo maximo configurado: 30 minutos.
- Retencion de logs: 7 dias.
- Sin servidores EC2 ni bases RDS permanentes.
- El presupuesto genera alertas, no bloquea el consumo.
- Costo efectivo de la prueba: pendiente de confirmacion.

## 6. Observaciones de seguridad

- Se verifico el funcionamiento del rol de CodeBuild.
- El rol cuenta con un permissions boundary.
- No se utilizaron credenciales de staging o produccion.
- Docker reporto una advertencia sobre su API local sin cifrado.
- Docker reporto la futura obsolescencia de cgroup v1.
- StartBuild conserva riesgos residuales de sobrescritura.
- La politica del ejecutor QA requiere aprobacion antes de asignarse.
- Los permisos temporales de aprovisionamiento fueron retirados el 2026-11-24.

## 7. Alcance de la validacion

La prueba confirma el funcionamiento de la infraestructura
remota de AWS CodeBuild y CloudWatch, incluyendo la creacion,
utilizacion y eliminacion de una base de datos temporal.

No se ejecutaron pruebas funcionales, unitarias ni de
integracion de los repositorios de la aplicacion.

La ejecucion de dichas pruebas corresponde al responsable QA.

## 8. Conclusion

La infraestructura de QA remoto fue desplegada y validada
satisfactoriamente mediante una prueba de humo en AWS.

El entorno queda tecnicamente preparado para la siguiente
etapa de validacion funcional por parte del equipo QA,
previa aprobacion y asignacion de los permisos de ejecucion.
