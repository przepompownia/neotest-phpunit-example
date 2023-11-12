<?php

namespace Arctgx\DapStrategy;

use PHPUnit\Framework\TestCase;

class TrivialTest extends TestCase
{
    public function testBrk(): void
    {
        print(microtime(true));
        self::assertTrue(true); 
    }
}
