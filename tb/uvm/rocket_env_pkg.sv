`ifndef ROCKET_ENV_PKG_SV
`define ROCKET_ENV_PKG_SV

// -------------------------------------------------------------------------
// File: rocket_env_pkg.sv
// Description: UVM Package for the Rocket core verification environment.
// -------------------------------------------------------------------------

package rocket_env_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // Forward declarations (optional, depending on dependencies)
  
  // Include sequence items
  `include "rocket_axi_item.sv"
  
  // Include sequences
  `include "rocket_sequences.sv"
  
  // Include components
  `include "rocket_axi_driver.sv"
  `include "rocket_axi_monitor.sv"
  `include "rocket_axi_agent.sv"
  
  `include "rocket_mem_agent.sv"
  
  `include "rocket_scoreboard.sv"
  `include "rocket_coverage.sv"
  
  // Include environment
  `include "rocket_env.sv"
  
  // Include tests
  `include "rocket_base_test.sv"

endpackage : rocket_env_pkg

`endif
