<?php


namespace AnsibleSnippetGenerator\Commands;

use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputArgument;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Twig\Environment;
use Twig\Loader\FilesystemLoader;
use Twig\TwigFunction;

class SnippetCommand extends Command
{
    private FilesystemLoader $loader;
    private Environment $twig;

    private string $baseDir;

    public function __construct(string $baseDir)
    {
        $this->baseDir = $baseDir;
        $this->loader = new FilesystemLoader($this->baseDir . DIRECTORY_SEPARATOR . 'templates');
        $this->twig = new Environment($this->loader, [
            'cache' => false,
            'autoescape' => false
        ]);

        $this->twig->addFunction(new TwigFunction('ansible_option', function ($option, $type, $index) {
            if (is_array($option)) {
                $option = current($option);
                $optionSplit = explode('.', $option);
                $option = current($optionSplit);
            }

            if ($type == 'bool') {
                $option = "true|false";
            }
            $encodedOption = json_encode($option);

            $encodedOption = substr($encodedOption, 1, strlen($encodedOption) - 2);
            return sprintf("\${%u:# %s}", $index, $encodedOption);
        }));


        parent::__construct('generate:snippet');
    }

    protected function configure()
    {
        $this
            ->setDescription('Generate snippets')
            ->setHelp('This command allows you to generate snippets')
            ->addArgument('template', InputArgument::REQUIRED, "Twig template to use")
            ->addArgument('input', InputArgument::REQUIRED, "Path to file to be used as input")
            ->addArgument('output', InputArgument::REQUIRED, 'Path to file for the snippet to be saved in');

        parent::configure();
    }

    protected function execute(InputInterface $input, OutputInterface $output)
    {
        $template = $this->twig->load($input->getArgument('template'));

        if (!file_exists($input->getArgument('input')) || !is_readable($input->getArgument('input'))) {
            $output->writeln('<error>Source file not readable</error>: ' . $input->getArgument('input'));
            return Command::FAILURE;
        }

        $moduleJsonString = file_get_contents($input->getArgument('input'));
        $moduleJson = json_decode($moduleJsonString, true);

        if (!is_array($moduleJson)) {
            $output->writeln('<error>Could not parse snippet</error>: ' . $input->getArgument('input'));
            return Command::FAILURE;
        }

        $moduleJsonKey = current(array_keys($moduleJson));

        if (is_null($moduleJsonKey)) {
            $output->writeln('<error>Could not retrieve module name</error>: ' . $input->getArgument('input'));
            return Command::FAILURE;
        }

        $snippetContent = $template->render(['module' => $moduleJson[$moduleJsonKey]['doc']]);
        file_put_contents($input->getArgument('output'), $snippetContent);

        return Command::SUCCESS;
    }

}