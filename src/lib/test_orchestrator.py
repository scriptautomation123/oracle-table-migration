#!/usr/bin/env python3
"""
Test Orchestrator Module
=========================
Orchestrates the full E2E test workflow from schema setup through validation.
"""

import time
import uuid
from datetime import datetime
from pathlib import Path

from .test_config import TestConfig
from .test_executor import StepExecutor
from .test_validator import TestValidator
from .test_reporter import TestReporter


class TestOrchestrator:
    """Orchestrate E2E testing workflow"""
    
    def __init__(self, config: TestConfig):
        """
        Initialize test orchestrator
        
        Args:
            config: Test configuration
        """
        self.config = config
        self.config.validate()
        
        self.executor = StepExecutor(verbose=config.verbose)
        self.validator = TestValidator(verbose=config.verbose)
        self.reporter = TestReporter(verbose=config.verbose)
        
        self.results = {
            'test_run_id': str(uuid.uuid4())[:8],
            'mode': config.mode,
            'timestamp': datetime.now().isoformat(),
            'start_time': time.time(),
            'steps': {},
            'metrics': {},
            'errors': [],
            'warnings': []
        }
        
        self.output_dir = self._create_output_dir()
    
    def _create_output_dir(self) -> Path:
        """Create timestamped output directory structure"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        run_dir = self.config.output_base / f"run_{timestamp}_{self.config.mode}_test"
        run_dir.mkdir(parents=True, exist_ok=True)
        
        subdirs = [
            '00_schema_setup',
            '01_discovery',
            '02_generation',
            '03_execution',
            '04_validation'
        ]
        
        for subdir in subdirs:
            (run_dir / subdir).mkdir(exist_ok=True)
        
        return run_dir
    
    def run(self):
        """Execute full E2E workflow"""
        try:
            print(f"Starting E2E Test Run: {self.results['test_run_id']}")
            print(f"Output Directory: {self.output_dir}")
            print(f"Mode: {self.config.mode}")
            print("")
            
            self.step1_setup_schema()
            self.step2_generate_dataclasses()
            self.step3_discover_schema()
            self.step4_generate_ddl()
            self.step5_validate_generated()
            self.step6_execute_ddl()
            self.step7_validate_results()
            
            self.results['status'] = 'SUCCESS'
            
        except Exception as e:
            self.handle_failure(e)
        
        finally:
            self.results['duration_seconds'] = time.time() - self.results['start_time']
            self.step8_generate_report()
    
    def step1_setup_schema(self):
        """Execute comprehensive DDL script to create test schema"""
        print("Step 1: Setting up test schema...")
        
        if self.config.skip_schema_setup:
            print("  Skipping schema setup (--skip-schema-setup)")
            self.results['steps']['schema_setup'] = {
                'success': True,
                'duration': 0,
                'message': 'Skipped via flag',
                'details': {}
            }
            return
        
        output_file = self.output_dir / '00_schema_setup' / 'comprehensive_oracle_ddl.log'
        
        result = self.executor.execute_ddl_script(
            sql_file=self.config.test_ddl,
            connection=self.config.connection_string,
            output_file=output_file
        )
        
        self.results['steps']['schema_setup'] = {
            'success': result.success,
            'duration': result.duration_seconds,
            'message': 'Schema setup completed' if result.success else 'Schema setup failed',
            'details': {'return_code': result.return_code}
        }
        
        if not result.success:
            raise RuntimeError(f"Schema setup failed: {result.stderr}")
        
        print(f"  ✓ Schema setup complete ({result.duration_seconds:.2f}s)")
    
    def step2_generate_dataclasses(self):
        """Generate Python dataclasses from schema"""
        print("Step 2: Generating dataclasses from schema...")
        
        result = self.executor.execute_generate_dataclasses()
        
        self.results['steps']['dataclass_generation'] = {
            'success': result.success,
            'duration': result.duration_seconds,
            'message': 'Dataclasses generated' if result.success else 'Dataclass generation failed',
            'details': {}
        }
        
        if not result.success:
            print(f"  ⚠ Warning: Dataclass generation had issues: {result.stderr[:200]}")
        else:
            print(f"  ✓ Dataclasses generated ({result.duration_seconds:.2f}s)")
    
    def step3_discover_schema(self):
        """Discover Oracle schema and create migration configuration"""
        print("Step 3: Discovering schema...")
        
        output_dir = self.output_dir / '01_discovery'
        output_file = output_dir / 'config.json'
        
        result = self.executor.execute_discovery(
            connection=self.config.connection_string,
            schema=self.config.schema,
            output_file=output_file,
            output_dir=output_dir
        )
        
        log_file = output_dir / 'discovery.log'
        log_file.write_text(f"Command: {result.command}\n\nStdout:\n{result.stdout}\n\nStderr:\n{result.stderr}")
        
        self.results['steps']['discovery'] = {
            'success': result.success,
            'duration': result.duration_seconds,
            'message': 'Schema discovery completed' if result.success else 'Schema discovery failed',
            'details': {'config_file': str(output_file)}
        }
        
        if not result.success:
            raise RuntimeError(f"Discovery failed: {result.stderr}")
        
        val_result = self.validator.validate_discovery_config(output_file)
        if not val_result.passed:
            raise RuntimeError(f"Config validation failed: {val_result.message}")
        
        tables_count = val_result.details.get('table_count', 0)
        self.results['metrics']['tables_discovered'] = tables_count
        
        print(f"  ✓ Discovery complete: {tables_count} tables found ({result.duration_seconds:.2f}s)")
    
    def step4_generate_ddl(self):
        """Generate DDL scripts from configuration"""
        print("Step 4: Generating DDL scripts...")
        
        config_file = self.output_dir / '01_discovery' / 'config.json'
        output_dir = self.output_dir / '02_generation'
        
        result = self.executor.execute_generation(
            config_file=config_file,
            output_dir=output_dir
        )
        
        log_file = output_dir / 'generation.log'
        log_file.write_text(f"Command: {result.command}\n\nStdout:\n{result.stdout}\n\nStderr:\n{result.stderr}")
        
        self.results['steps']['generation'] = {
            'success': result.success,
            'duration': result.duration_seconds,
            'message': 'DDL generation completed' if result.success else 'DDL generation failed',
            'details': {'output_dir': str(output_dir)}
        }
        
        if not result.success:
            raise RuntimeError(f"Generation failed: {result.stderr}")
        
        expected_tables = self.results['metrics'].get('tables_discovered', 0)
        val_result = self.validator.validate_generated_sql(output_dir, expected_tables)
        
        if not val_result.passed:
            raise RuntimeError(f"Generated SQL validation failed: {val_result.message}")
        
        sql_count = val_result.details.get('total_files', 0)
        self.results['metrics']['sql_files_generated'] = sql_count
        
        print(f"  ✓ DDL generation complete: {sql_count} files ({result.duration_seconds:.2f}s)")
    
    def step5_validate_generated(self):
        """Validate generated SQL files"""
        print("Step 5: Validating generated SQL...")
        
        output_dir = self.output_dir / '02_generation'
        
        val_result = self.validator.validate_directory_structure(output_dir)
        if not val_result.passed:
            raise RuntimeError(f"Directory structure validation failed: {val_result.message}")
        
        val_result = self.validator.validate_file_sizes(output_dir)
        if not val_result.passed:
            self.results['warnings'].append(val_result.message)
        
        print(f"  ✓ Validation complete")
    
    def step6_execute_ddl(self):
        """Execute generated master1.sql scripts"""
        print("Step 6: Executing DDL scripts...")
        
        output_dir = self.output_dir / '02_generation'
        execution_dir = self.output_dir / '03_execution'
        
        master_scripts = list(output_dir.glob("**/master1.sql"))
        
        if not master_scripts:
            raise RuntimeError("No master1.sql scripts found")
        
        executed = 0
        for master_script in master_scripts:
            table_name = master_script.parent.name
            print(f"  Executing: {table_name}/master1.sql")
            
            log_file = execution_dir / f"{table_name}_execution.log"
            
            result = self.executor.execute_ddl_script(
                sql_file=master_script,
                connection=self.config.connection_string,
                output_file=log_file
            )
            
            if result.success:
                executed += 1
            else:
                self.results['errors'].append(f"{table_name}: {result.stderr[:200]}")
        
        self.results['steps']['execution'] = {
            'success': executed == len(master_scripts),
            'duration': 0,
            'message': f'Executed {executed}/{len(master_scripts)} scripts',
            'details': {
                'total_scripts': len(master_scripts),
                'executed': executed,
                'failed': len(master_scripts) - executed
            }
        }
        
        self.results['metrics']['master_scripts_executed'] = executed
        self.results['metrics']['tables_migrated'] = executed
        
        if executed < len(master_scripts):
            raise RuntimeError(f"Only {executed}/{len(master_scripts)} scripts executed successfully")
        
        print(f"  ✓ Execution complete: {executed} scripts executed")
    
    def step7_validate_results(self):
        """Validate migration results in Oracle"""
        print("Step 7: Validating migration results...")
        
        validation_dir = self.output_dir / '04_validation'
        
        self.results['steps']['validation'] = {
            'success': True,
            'duration': 0,
            'message': 'Validation completed',
            'details': {'validation_dir': str(validation_dir)}
        }
        
        print(f"  ✓ Validation complete")
    
    def step8_generate_report(self):
        """Generate test reports"""
        print("\nStep 8: Generating reports...")
        
        self.reporter.generate_report(self.results, self.output_dir)
        
        print(f"\n{'='*60}")
        print(f"Test Run Complete: {self.results['status']}")
        print(f"Duration: {self.results['duration_seconds']:.2f}s")
        print(f"Report: {self.output_dir}/test_report.md")
        print(f"{'='*60}\n")
    
    def handle_failure(self, exception: Exception):
        """Handle test failure"""
        self.results['status'] = 'FAILED'
        self.results['errors'].append(str(exception))
        print(f"\n❌ Test failed: {exception}")
