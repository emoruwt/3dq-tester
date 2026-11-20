M2 architecture templates (not a working complete design)

Modules:
 milestone2.sv: parent FSM skeleton; children and RAM muxes not yet instantiated.
 m2_fetch_sprime.sv: SRAM S-prime block address generator and fetch controller.
 m2_compute_t.sv: shared operand, two parallel T accumulators.
 m2_compute_s.sv: shared T operand, two parallel S accumulators.
 m2_write_s.sv: read unpacked S samples and pack for SRAM.

CRITICAL BEFORE SIMULATION/INTEGRATION:
 1. Parent state progression at plane boundaries is illustrative and must be corrected with explicit block descriptors.
 2. Shared multiplier and BRAM arbitration/muxing is not implemented; only one physical pair of multipliers is permitted.
 3. BRAM3 port conflict in Mega A: two S writes + S-prime fetch may exceed two ports. Buffer or schedule writes.
 4. Model true SRAM/BRAM read latency and requests/valid handshake; align counters to returned data.
 5. Apply the project's exact fixed-point scaling, rounding and clipping (currently TODO placeholders).
 6. Pipeline T and S writeback so multiplier utilization meets the project requirement.
 7. Add proper C8 constant table/mux with the project's real coefficient values.
 8. Validate address arithmetic widths and signedness in Quartus.
 9. BRAM3 S addresses use 128..255 (unpacked), S-prime 0..127.
10. Write S assumes BRAM output valid is explicitly supplied and SRAM writes accepted each W_WRITE.

Use these as a structured starting point, not synthesizable final deliverables.
